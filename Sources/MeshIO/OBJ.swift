import Foundation

/// Native Wavefront OBJ reader/writer (geometry only: `v` + `f`). Faces of any vertex-ref form
/// (`v`, `v/vt`, `v/vt/vn`, `v//vn`; negative-relative indices) are fan-triangulated. No OCCT.
public enum OBJ {

    public static func read(data: Data, weldEpsilon: Float = 1e-4) throws -> Mesh {
        guard !data.isEmpty else { throw MeshError.empty }
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let b = raw.bindMemory(to: UInt8.self); let n = b.count; var i = 0
            while i < n {
                while i < n, b[i] == 32 || b[i] == 9 { i += 1 }
                let s = i; while i < n, b[i] != 10 { i += 1 }; let e = i; i += 1
                guard e > s else { continue }
                let c0 = b[s]
                let sep = s + 1 < e && (b[s + 1] == 32 || b[s + 1] == 9)
                if c0 == UInt8(ascii: "v"), sep { parseVertex(b, s + 1, e, &positions) }
                else if c0 == UInt8(ascii: "f"), sep { parseFace(b, s + 1, e, positions.count, &indices) }
            }
        }
        guard !positions.isEmpty, !indices.isEmpty else { throw MeshError.notRecognized }
        if weldEpsilon > 0 {
            var soup = [SIMD3<Float>](); soup.reserveCapacity(indices.count)
            for idx in indices { soup.append(positions[Int(idx)]) }
            return Mesh.welded(soup, epsilon: weldEpsilon)
        }
        return Mesh(positions: positions, indices: indices)
    }

    private static func parseVertex(_ b: UnsafeBufferPointer<UInt8>, _ from: Int, _ to: Int, _ out: inout [SIMD3<Float>]) {
        var p = from, v = [Float]()
        while p < to, v.count < 3 {
            while p < to, b[p] == 32 || b[p] == 9 { p += 1 }
            let s = p; while p < to, b[p] != 32, b[p] != 9, b[p] != 13 { p += 1 }
            if p > s, let f = Float(String(decoding: UnsafeBufferPointer(rebasing: b[s..<p]), as: UTF8.self)) { v.append(f) }
        }
        if v.count == 3 { out.append(SIMD3(v[0], v[1], v[2])) }
    }

    private static func parseFace(_ b: UnsafeBufferPointer<UInt8>, _ from: Int, _ to: Int, _ vcount: Int, _ out: inout [UInt32]) {
        var p = from; var verts = [UInt32]()
        while p < to {
            while p < to, b[p] == 32 || b[p] == 9 { p += 1 }
            let s = p; while p < to, b[p] != 32, b[p] != 9, b[p] != 13 { p += 1 }
            if p > s {
                var e = s; while e < p, b[e] != UInt8(ascii: "/") { e += 1 }
                if let raw = Int(String(decoding: UnsafeBufferPointer(rebasing: b[s..<e]), as: UTF8.self)) {
                    let idx = raw > 0 ? raw - 1 : vcount + raw
                    if idx >= 0, idx < vcount { verts.append(UInt32(idx)) }
                }
            }
        }
        guard verts.count >= 3 else { return }
        for k in 1..<(verts.count - 1) { out.append(verts[0]); out.append(verts[k]); out.append(verts[k + 1]) }
    }

    // MARK: write

    public static func string(_ mesh: Mesh) -> String {
        var s = "# MeshIO OBJ — \(mesh.vertexCount) verts, \(mesh.triangleCount) tris\n"
        s.reserveCapacity(mesh.vertexCount * 24 + mesh.triangleCount * 16)
        for p in mesh.positions { s += "v \(p.x) \(p.y) \(p.z)\n" }
        for t in 0..<mesh.triangleCount {
            let (a, b, c) = mesh.triangle(t)
            s += "f \(a + 1) \(b + 1) \(c + 1)\n"
        }
        return s
    }
}
