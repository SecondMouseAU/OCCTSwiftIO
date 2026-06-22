import Foundation

/// Native PLY reader/writer. Reads ASCII and binary-little-endian PLY: the `vertex` element's
/// x/y/z and the `face` element's index lists (fan-triangulated). No OCCT.
public enum PLY {

    public static func read(data: Data, weldEpsilon: Float = 1e-4) throws -> Mesh {
        guard !data.isEmpty else { throw MeshError.empty }
        let bytes = [UInt8](data)
        guard bytes.count >= 3, bytes[0] == UInt8(ascii: "p"), bytes[1] == UInt8(ascii: "l"), bytes[2] == UInt8(ascii: "y")
        else { throw MeshError.notRecognized }

        // --- header ---
        var headerEnd = 0
        var lines: [String] = []
        do {
            var line = [UInt8](); var i = 0
            while i < bytes.count {
                let ch = bytes[i]; i += 1
                if ch == 10 {
                    let s = String(decoding: line, as: UTF8.self).trimmingCharacters(in: .whitespaces)
                    lines.append(s); line.removeAll(keepingCapacity: true)
                    if s == "end_header" { headerEnd = i; break }
                } else if ch != 13 { line.append(ch) }
            }
        }
        var binary = false, bigEndian = false
        struct Prop { var name: String; var size: Int; var isFloat: Bool }
        struct ListProp { var countSize: Int; var indexSize: Int }
        var vertexCount = 0, faceCount = 0
        var vProps: [Prop] = []; var faceList: ListProp?
        var current = ""   // which element we're describing
        func tsize(_ t: String) -> (Int, Bool) {
            switch t {
            case "char", "uchar", "int8", "uint8": return (1, false)
            case "short", "ushort", "int16", "uint16": return (2, false)
            case "int", "uint", "int32", "uint32": return (4, false)
            case "float", "float32": return (4, true)
            case "double", "float64": return (8, true)
            default: return (4, false)
            }
        }
        for l in lines {
            let f = l.split(separator: " ").map(String.init)
            guard let kw = f.first else { continue }
            switch kw {
            case "format": binary = l.contains("binary"); bigEndian = l.contains("big_endian")
            case "element":
                current = f[1]
                if f[1] == "vertex" { vertexCount = Int(f[2]) ?? 0 }
                else if f[1] == "face" { faceCount = Int(f[2]) ?? 0 }
            case "property":
                if f[1] == "list", current == "face" {
                    faceList = ListProp(countSize: tsize(f[2]).0, indexSize: tsize(f[3]).0)
                } else if current == "vertex" {
                    let (sz, isF) = tsize(f[1]); vProps.append(Prop(name: f.last ?? "", size: sz, isFloat: isF))
                }
            default: break
            }
        }
        let xi = vProps.firstIndex { $0.name == "x" } ?? 0
        let yi = vProps.firstIndex { $0.name == "y" } ?? 1
        let zi = vProps.firstIndex { $0.name == "z" } ?? 2

        var positions: [SIMD3<Float>] = []; positions.reserveCapacity(vertexCount)
        var faces: [[Int]] = []; faces.reserveCapacity(faceCount)

        if !binary {
            // ASCII body
            let body = String(decoding: bytes[headerEnd...], as: UTF8.self)
            var it = body.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).makeIterator()
            for _ in 0..<vertexCount {
                guard let row = it.next() else { break }
                let v = row.split(separator: " ").compactMap { Float($0) }
                if v.count > max(xi, yi, zi) { positions.append(SIMD3(v[xi], v[yi], v[zi])) }
            }
            for _ in 0..<faceCount {
                guard let row = it.next() else { break }
                let v = row.split(separator: " ").compactMap { Int($0) }
                guard let k = v.first, k >= 3, v.count >= k + 1 else { continue }
                faces.append(Array(v[1...k]))
            }
        } else {
            guard !bigEndian else { throw MeshError.unsupported("PLY big-endian") }
            var p = headerEnd
            let stride = vProps.reduce(0) { $0 + $1.size }
            let offs = vProps.reduce(into: (run: 0, arr: [Int]())) { acc, pr in acc.arr.append(acc.run); acc.run += pr.size }.arr
            func f(_ at: Int, _ pr: Prop) -> Float {
                if pr.isFloat {
                    return pr.size == 8
                        ? Float(bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: at, as: Double.self) })
                        : bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: at, as: Float.self) }
                }
                return Float(readInt(bytes, at, pr.size))
            }
            for _ in 0..<vertexCount {
                guard p + stride <= bytes.count else { break }
                positions.append(SIMD3(f(p + offs[xi], vProps[xi]), f(p + offs[yi], vProps[yi]), f(p + offs[zi], vProps[zi])))
                p += stride
            }
            if let fl = faceList {
                for _ in 0..<faceCount {
                    guard p + fl.countSize <= bytes.count else { break }
                    let k = readInt(bytes, p, fl.countSize); p += fl.countSize
                    var idx = [Int](); idx.reserveCapacity(k)
                    for _ in 0..<k { guard p + fl.indexSize <= bytes.count else { break }; idx.append(readInt(bytes, p, fl.indexSize)); p += fl.indexSize }
                    if idx.count >= 3 { faces.append(idx) }
                }
            }
        }

        var indices: [UInt32] = []
        for face in faces where face.count >= 3 {
            for k in 1..<(face.count - 1) where face[0] < positions.count && face[k] < positions.count && face[k + 1] < positions.count {
                indices.append(UInt32(face[0])); indices.append(UInt32(face[k])); indices.append(UInt32(face[k + 1]))
            }
        }
        guard !positions.isEmpty, !indices.isEmpty else { throw MeshError.notRecognized }
        if weldEpsilon > 0 {
            var soup = [SIMD3<Float>](); soup.reserveCapacity(indices.count)
            for i in indices { soup.append(positions[Int(i)]) }
            return Mesh.welded(soup, epsilon: weldEpsilon)
        }
        return Mesh(positions: positions, indices: indices)
    }

    private static func readInt(_ b: [UInt8], _ at: Int, _ size: Int) -> Int {
        var v = 0; for k in 0..<size { v |= Int(b[at + k]) << (8 * k) }; return v
    }

    // MARK: write (ASCII)

    public static func string(_ mesh: Mesh) -> String {
        var s = "ply\nformat ascii 1.0\ncomment MeshIO\n"
        s += "element vertex \(mesh.vertexCount)\nproperty float x\nproperty float y\nproperty float z\n"
        s += "element face \(mesh.triangleCount)\nproperty list uchar int vertex_indices\nend_header\n"
        s.reserveCapacity(mesh.vertexCount * 24 + mesh.triangleCount * 16)
        for p in mesh.positions { s += "\(p.x) \(p.y) \(p.z)\n" }
        for t in 0..<mesh.triangleCount { let (a, b, c) = mesh.triangle(t); s += "3 \(a) \(b) \(c)\n" }
        return s
    }
}
