import Foundation
import simd
import SwiftGLTF

extension MeshIO {

    // MARK: read (via SwiftGLTF)

    /// Read **glTF** / **GLB** into a ``Mesh``. SwiftGLTF handles the hard decoding (JSON/GLB container,
    /// buffers, external `.bin`, accessors); we walk the scene graph, decode POSITION + index accessors
    /// ourselves (avoiding SwiftGLTF's RealityKit-importing convenience helpers), and bake node transforms.
    static func readGLTF(url: URL, weldEpsilon: Float) throws -> Mesh {
        let container = try SwiftGLTF.Container(url: url)
        let doc = container.document
        var soup: [SIMD3<Float>] = []

        func positions(_ acc: SwiftGLTF.Accessor) throws -> [SIMD3<Float>] {
            let d = try container.data(for: acc)
            var out = [SIMD3<Float>](); out.reserveCapacity(acc.count)
            d.withUnsafeBytes { raw in
                for i in 0..<acc.count {
                    let o = i * 12
                    out.append(SIMD3(raw.loadUnaligned(fromByteOffset: o, as: Float.self),
                                     raw.loadUnaligned(fromByteOffset: o + 4, as: Float.self),
                                     raw.loadUnaligned(fromByteOffset: o + 8, as: Float.self)))
                }
            }
            return out
        }
        func indices(_ acc: SwiftGLTF.Accessor) throws -> [Int] {
            let d = try container.data(for: acc)
            var out = [Int](); out.reserveCapacity(acc.count)
            d.withUnsafeBytes { raw in
                for i in 0..<acc.count {
                    switch acc.componentType {
                    case .UNSIGNED_BYTE:  out.append(Int(raw.loadUnaligned(fromByteOffset: i, as: UInt8.self)))
                    case .UNSIGNED_SHORT: out.append(Int(raw.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self)))
                    case .UNSIGNED_INT:   out.append(Int(raw.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self)))
                    default: break
                    }
                }
            }
            return out
        }
        func local(_ n: SwiftGLTF.Node) -> simd_float4x4 {
            if let m = n.matrix, m != matrix_identity_float4x4 { return m }   // matrix XOR TRS per spec
            var t = matrix_identity_float4x4
            if let s = n.scale { t = simd_float4x4(diagonal: SIMD4(s, 1)) }
            if let r = n.rotation { t = simd_float4x4(simd_quatf(ix: r.x, iy: r.y, iz: r.z, r: r.w)) * t }
            if let tr = n.translation { var tm = matrix_identity_float4x4; tm.columns.3 = SIMD4(tr, 1); t = tm * t }
            return t
        }
        func emit(_ prim: SwiftGLTF.Mesh.Primitive, _ world: simd_float4x4) throws {
            guard prim.mode == .TRIANGLES, let posIdx = prim.attributes[.POSITION] else { return }
            let pos = try positions(posIdx.resolve(in: doc))
            let wp = pos.map { p -> SIMD3<Float> in let v = world * SIMD4(p, 1); return SIMD3(v.x, v.y, v.z) }
            let idx = try prim.indices.map { try indices($0.resolve(in: doc)) } ?? Array(0..<wp.count)
            var t = 0
            while t + 2 < idx.count {
                let a = idx[t], b = idx[t + 1], c = idx[t + 2]; t += 3
                if a < wp.count, b < wp.count, c < wp.count { soup.append(wp[a]); soup.append(wp[b]); soup.append(wp[c]) }
            }
        }
        func walk(_ node: SwiftGLTF.Node, _ parent: simd_float4x4) throws {
            let world = parent * local(node)
            if let meshIdx = node.mesh {
                for prim in try meshIdx.resolve(in: doc).primitives { try emit(prim, world) }
            }
            for child in node.children { try walk(child.resolve(in: doc), world) }
        }

        let roots: [SwiftGLTF.Index<SwiftGLTF.Node>] =
            (try doc.scene?.resolve(in: doc).nodes) ?? doc.scenes.first?.nodes ?? []
        for r in roots { try walk(r.resolve(in: doc), matrix_identity_float4x4) }
        if soup.isEmpty {                                          // no scene graph → meshes untransformed
            for mesh in doc.meshes { for prim in mesh.primitives { try emit(prim, matrix_identity_float4x4) } }
        }
        guard !soup.isEmpty else { throw MeshError.notRecognized }
        return weldEpsilon > 0 ? Mesh.welded(soup, epsilon: weldEpsilon) : Mesh.indexedSoup(soup)
    }

    // MARK: write (native glTF / GLB)

    /// Pack a mesh into a single glTF buffer (positions float32 VEC3, then indices uint32 SCALAR) and
    /// produce the JSON manifest. `bufferURI` is nil for GLB (BIN chunk) or a data URI for `.gltf`.
    private static func gltfBin(_ mesh: Mesh) -> (bin: Data, posLen: Int, idxLen: Int, lo: SIMD3<Float>, hi: SIMD3<Float>) {
        var bin = [UInt8]()
        func f32(_ v: Float) { var x = v.bitPattern.littleEndian; withUnsafeBytes(of: &x) { bin.append(contentsOf: $0) } }
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { bin.append(contentsOf: $0) } }
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
        for p in mesh.positions { f32(p.x); f32(p.y); f32(p.z); lo = simd_min(lo, p); hi = simd_max(hi, p) }
        let posLen = bin.count
        for i in mesh.indices { u32(i) }
        return (Data(bin), posLen, bin.count - posLen, lo, hi)
    }

    private static func gltfManifest(_ mesh: Mesh, _ b: (bin: Data, posLen: Int, idxLen: Int, lo: SIMD3<Float>, hi: SIMD3<Float>), bufferURI: String?) -> String {
        func n(_ v: Float) -> String { String(v) }
        let buffer = bufferURI.map { "{\"uri\":\"\($0)\",\"byteLength\":\(b.bin.count)}" } ?? "{\"byteLength\":\(b.bin.count)}"
        return "{\"asset\":{\"version\":\"2.0\",\"generator\":\"MeshIO\"},"
            + "\"buffers\":[\(buffer)],"
            + "\"bufferViews\":[{\"buffer\":0,\"byteOffset\":0,\"byteLength\":\(b.posLen),\"target\":34962},"
            + "{\"buffer\":0,\"byteOffset\":\(b.posLen),\"byteLength\":\(b.idxLen),\"target\":34963}],"
            + "\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":\(mesh.vertexCount),\"type\":\"VEC3\","
            + "\"min\":[\(n(b.lo.x)),\(n(b.lo.y)),\(n(b.lo.z))],\"max\":[\(n(b.hi.x)),\(n(b.hi.y)),\(n(b.hi.z))]},"
            + "{\"bufferView\":1,\"componentType\":5125,\"count\":\(mesh.indices.count),\"type\":\"SCALAR\"}],"
            + "\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0},\"indices\":1,\"mode\":4}]}],"
            + "\"nodes\":[{\"mesh\":0}],\"scenes\":[{\"nodes\":[0]}],\"scene\":0}"
    }

    /// `.gltf` — JSON with the buffer embedded as a base64 data URI (self-contained, no sidecar `.bin`).
    static func writeGLTF(_ mesh: Mesh) -> Data {
        let b = gltfBin(mesh)
        let json = gltfManifest(mesh, b, bufferURI: "data:application/octet-stream;base64,\(b.bin.base64EncodedString())")
        return Data(json.utf8)
    }

    /// `.glb` — binary container: 12-byte header + JSON chunk + BIN chunk (each 4-byte aligned).
    static func writeGLB(_ mesh: Mesh) -> Data {
        let b = gltfBin(mesh)
        var json = [UInt8](gltfManifest(mesh, b, bufferURI: nil).utf8)
        while json.count % 4 != 0 { json.append(0x20) }          // pad JSON with spaces
        var bin = [UInt8](b.bin)
        while bin.count % 4 != 0 { bin.append(0x00) }            // pad BIN with zeros
        var d = Data()
        func u32(_ v: Int) { var x = UInt32(v).littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        u32(0x46546C67); u32(2); u32(12 + 8 + json.count + 8 + bin.count)   // "glTF", version 2, total length
        u32(json.count); u32(0x4E4F534A); d.append(contentsOf: json)        // JSON chunk ("JSON")
        u32(bin.count);  u32(0x004E4942); d.append(contentsOf: bin)         // BIN chunk ("BIN\0")
        return d
    }
}
