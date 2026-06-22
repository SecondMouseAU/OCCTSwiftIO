import Foundation

/// Native STL reader/writer (ASCII + binary). No OCCT.
public enum STL {

    public static func read(data: Data, weldEpsilon: Float = 1e-4) throws -> Mesh {
        guard !data.isEmpty else { throw MeshError.empty }
        let soup = looksBinary(data) ? readBinary(data) : readASCII(data)
        guard !soup.isEmpty else { throw MeshError.notRecognized }
        return Mesh.welded(soup, epsilon: weldEpsilon)
    }

    /// Binary STL is a fixed layout: 80-byte header + UInt32 count + 50 bytes/triangle.
    static func looksBinary(_ data: Data) -> Bool {
        guard data.count >= 84 else { return false }
        let n = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 80, as: UInt32.self) }
        return data.count == 84 + 50 * Int(n)
    }

    static func readBinary(_ data: Data) -> [SIMD3<Float>] {
        let n = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 80, as: UInt32.self) })
        guard data.count >= 84 + 50 * n else { return [] }
        var out = [SIMD3<Float>](); out.reserveCapacity(n * 3)
        data.withUnsafeBytes { raw in
            let base = raw.baseAddress!
            for i in 0..<n {
                var off = 84 + i * 50 + 12                       // skip the 12-byte normal
                for _ in 0..<3 {
                    let x = base.loadUnaligned(fromByteOffset: off, as: Float.self)
                    let y = base.loadUnaligned(fromByteOffset: off + 4, as: Float.self)
                    let z = base.loadUnaligned(fromByteOffset: off + 8, as: Float.self)
                    out.append(SIMD3(x, y, z)); off += 12
                }
            }
        }
        return out
    }

    static func readASCII(_ data: Data) -> [SIMD3<Float>] {
        var out = [SIMD3<Float>]()
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let b = raw.bindMemory(to: UInt8.self); let n = b.count
            var i = 0
            while i < n {
                while i < n, b[i] == 32 || b[i] == 9 { i += 1 }
                let s = i; while i < n, b[i] != 10 { i += 1 }; let e = i; i += 1
                let kw: [UInt8] = [118, 101, 114, 116, 101, 120]   // "vertex"
                guard e - s >= 7 else { continue }
                var ok = true; for k in 0..<6 where b[s + k] != kw[k] { ok = false }
                guard ok else { continue }
                var p = s + 6; var c = [Float]()
                while p < e, c.count < 3 {
                    while p < e, b[p] == 32 || b[p] == 9 { p += 1 }
                    let t = p; while p < e, b[p] != 32, b[p] != 9, b[p] != 13 { p += 1 }
                    if p > t, let f = Float(String(decoding: UnsafeBufferPointer(rebasing: b[t..<p]), as: UTF8.self)) { c.append(f) }
                }
                if c.count == 3 { out.append(SIMD3(c[0], c[1], c[2])) }
            }
        }
        return out
    }

    // MARK: write

    public static func binaryData(_ mesh: Mesh) -> Data {
        var data = Data(capacity: 84 + mesh.triangleCount * 50)
        data.append(Data(count: 80))
        var nn = UInt32(mesh.triangleCount); withUnsafeBytes(of: &nn) { data.append(contentsOf: $0) }
        func f(_ v: Float) { var x = v; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        for t in 0..<mesh.triangleCount {
            let (a, b, c) = mesh.trianglePositions(t)
            let nrm = normal(a, b, c)
            f(nrm.x); f(nrm.y); f(nrm.z)
            for p in [a, b, c] { f(p.x); f(p.y); f(p.z) }
            data.append(contentsOf: [0, 0])
        }
        return data
    }

    public static func asciiString(_ mesh: Mesh, name: String = "mesh") -> String {
        var s = "solid \(name)\n"; s.reserveCapacity(mesh.triangleCount * 160)
        for t in 0..<mesh.triangleCount {
            let (a, b, c) = mesh.trianglePositions(t); let nrm = normal(a, b, c)
            s += "  facet normal \(nrm.x) \(nrm.y) \(nrm.z)\n    outer loop\n"
            for p in [a, b, c] { s += "      vertex \(p.x) \(p.y) \(p.z)\n" }
            s += "    endloop\n  endfacet\n"
        }
        return s + "endsolid \(name)\n"
    }

    static func normal(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> SIMD3<Float> {
        let u = b - a, v = c - a
        let n = SIMD3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x)
        let len = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
        return len > 1e-12 ? n / len : SIMD3(0, 0, 1)
    }
}
