import Foundation
import Testing

@testable import MeshIO

/// Holds what the OBJ and PLY readers return for indexed input, at each weld epsilon.
///
/// The fixture has 7 stored vertices and 4 triangles (#30):
///
/// - `p4` is within the default epsilon of `p0`, so welding merges them.
/// - `p6` is 0.001 above `p2`: distinct at the default epsilon, merged at 0.01.
/// - `p5` is stored but no triangle uses it.
@Suite("Indexed readers weld the way they did before the shared initialiser")
struct MeshWeldCharacterizationTests {

    static let p0 = SIMD3<Float>(0, 0, 0)
    static let p1 = SIMD3<Float>(1, 0, 0)
    static let p2 = SIMD3<Float>(1, 1, 0)
    static let p3 = SIMD3<Float>(0, 1, 0)
    static let p4 = SIMD3<Float>(0.00001, 0, 0)
    static let p5 = SIMD3<Float>(5, 5, 5)
    static let p6 = SIMD3<Float>(1, 1, 0.001)

    /// The stored vertices, in file order.
    static let stored = [p0, p1, p2, p3, p4, p5, p6]
    /// The four triangles as stored vertex numbers (0-based).
    static let storedFaces: [[Int]] = [[0, 1, 2], [0, 2, 3], [4, 1, 2], [6, 2, 3]]

    /// At the default 1e-4: `p4` joins `p0`, `p6` stays, `p5` is dropped, and a merged corner keeps the
    /// position it was first seen at.
    static let weldedDefault = Mesh(
        positions: [p0, p1, p2, p3, p6],
        indices: [0, 1, 2, 0, 2, 3, 0, 1, 2, 4, 2, 3])

    /// At 0.01: `p6` joins `p2`, which leaves the last triangle with two equal corners; welding
    /// does not drop it.
    static let weldedCoarse = Mesh(
        positions: [p0, p1, p2, p3],
        indices: [0, 1, 2, 0, 2, 3, 0, 1, 2, 2, 2, 3])

    /// With no welding: every stored vertex stays, `p5` included, and the indices are as stored.
    static let unwelded = Mesh(
        positions: stored,
        indices: [0, 1, 2, 0, 2, 3, 4, 1, 2, 6, 2, 3])

    // MARK: fixtures

    static var objData: Data {
        var s = "# weld fixture\n"
        for p in stored { s += "v \(p.x) \(p.y) \(p.z)\n" }
        for f in storedFaces { s += "f \(f[0] + 1) \(f[1] + 1) \(f[2] + 1)\n" }
        return Data(s.utf8)
    }

    static var plyASCIIData: Data {
        var s = "ply\nformat ascii 1.0\n"
        s += "element vertex \(stored.count)\n"
        s += "property float x\nproperty float y\nproperty float z\n"
        s += "element face \(storedFaces.count)\nproperty list uchar int vertex_indices\n"
        s += "end_header\n"
        for p in stored { s += "\(p.x) \(p.y) \(p.z)\n" }
        for f in storedFaces { s += "3 \(f[0]) \(f[1]) \(f[2])\n" }
        return Data(s.utf8)
    }

    static var plyBinaryData: Data {
        var d = Data()
        var header = "ply\nformat binary_little_endian 1.0\n"
        header +=
            "element vertex \(stored.count)\nproperty float x\nproperty float y\nproperty float z\n"
        header += "element face \(storedFaces.count)\nproperty list uchar int vertex_indices\n"
        header += "end_header\n"
        d.append(contentsOf: Array(header.utf8))
        for p in stored {
            for c in [p.x, p.y, p.z] {
                withUnsafeBytes(of: c.bitPattern.littleEndian) { d.append(contentsOf: $0) }
            }
        }
        for f in storedFaces {
            d.append(3)
            for i in f {
                withUnsafeBytes(of: Int32(i).littleEndian) { d.append(contentsOf: $0) }
            }
        }
        return d
    }

    // MARK: the readers

    static let readers: [(name: String, read: @Sendable (Float) throws -> Mesh)] = [
        ("OBJ", { try OBJ.read(data: objData, weldEpsilon: $0) }),
        ("PLY ascii", { try PLY.read(data: plyASCIIData, weldEpsilon: $0) }),
        ("PLY binary", { try PLY.read(data: plyBinaryData, weldEpsilon: $0) }),
    ]

    @Test("the default epsilon merges the near vertex, keeps the far one, drops the unused one")
    func t_defaultEpsilonWelds() throws {
        for r in Self.readers {
            let mesh = try r.read(1e-4)
            #expect(mesh.vertexCount == 5, "\(r.name) vertex count")
            #expect(mesh.triangleCount == 4, "\(r.name) triangle count")
            #expect(mesh == Self.weldedDefault, "\(r.name) positions and indices")
        }
    }

    @Test("the default argument is 1e-4")
    func t_defaultArgumentIsOneEMinusFour() throws {
        #expect(try OBJ.read(data: Self.objData) == Self.weldedDefault)
        #expect(try PLY.read(data: Self.plyASCIIData) == Self.weldedDefault)
        #expect(try PLY.read(data: Self.plyBinaryData) == Self.weldedDefault)
    }

    @Test("a coarser epsilon also merges the vertex 0.001 away, and keeps the degenerate triangle")
    func t_coarseEpsilonMergesMore() throws {
        for r in Self.readers {
            let mesh = try r.read(0.01)
            #expect(mesh.vertexCount == 4, "\(r.name) vertex count")
            #expect(mesh.triangleCount == 4, "\(r.name) triangle count")
            #expect(mesh == Self.weldedCoarse, "\(r.name) positions and indices")
        }
    }

    @Test("an epsilon of 0 keeps the stored vertices and indices, unused vertex included")
    func t_zeroEpsilonKeepsStoredIndexing() throws {
        for r in Self.readers {
            let mesh = try r.read(0)
            #expect(mesh.vertexCount == 7, "\(r.name) vertex count")
            #expect(mesh.triangleCount == 4, "\(r.name) triangle count")
            #expect(mesh == Self.unwelded, "\(r.name) positions and indices")
        }
    }

    @Test("a negative epsilon does not weld either")
    func t_negativeEpsilonKeepsStoredIndexing() throws {
        for r in Self.readers {
            #expect(try r.read(-1) == Self.unwelded, "\(r.name)")
        }
    }

    @Test("readers set no submeshes")
    func t_noSubmeshes() throws {
        for r in Self.readers {
            #expect(try r.read(1e-4).submeshes.isEmpty, "\(r.name)")
            #expect(try r.read(0).submeshes.isEmpty, "\(r.name)")
        }
    }
}
