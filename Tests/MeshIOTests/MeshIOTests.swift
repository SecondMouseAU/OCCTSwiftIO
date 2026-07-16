import Testing
import Foundation
@testable import MeshIO

@Suite("MeshIO round-trips")
struct MeshIOTests {

    /// A simple two-triangle quad with a distinctive bbox.
    static let quad = Mesh(
        positions: [.init(0, 0, 0), .init(2, 0, 0), .init(2, 3, 0), .init(0, 3, 5)],
        indices: [0, 1, 2, 0, 2, 3]
    )

    func roundTrip(_ fmt: MeshFormat, ascii: Bool = false) throws -> Mesh {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mio-\(UUID().uuidString).\(fmt.rawValue)")
        try MeshIO.write(Self.quad, to: url, format: fmt, asciiSTL: ascii)
        defer { try? FileManager.default.removeItem(at: url) }
        return try MeshIO.load(contentsOf: url)
    }

    @Test("STL binary round-trips geometry")
    func stlBinary() throws {
        let m = try roundTrip(.stl)
        #expect(m.triangleCount == 2)
        let b = try #require(m.bounds)
        #expect(abs(b.max.x - 2) < 1e-5 && abs(b.max.y - 3) < 1e-5 && abs(b.max.z - 5) < 1e-5)
    }

    @Test("STL ascii round-trips geometry")
    func stlASCII() throws {
        let m = try roundTrip(.stl, ascii: true)
        #expect(m.triangleCount == 2)
        #expect(abs((m.bounds?.max.z ?? 0) - 5) < 1e-4)
    }

    @Test("OBJ round-trips geometry and indexing")
    func obj() throws {
        let m = try roundTrip(.obj)
        #expect(m.triangleCount == 2 && m.vertexCount == 4)
        #expect(abs((m.bounds?.max.z ?? 0) - 5) < 1e-5)
    }

    @Test("PLY round-trips geometry and indexing")
    func ply() throws {
        let m = try roundTrip(.ply)
        #expect(m.triangleCount == 2 && m.vertexCount == 4)
        #expect(abs((m.bounds?.max.z ?? 0) - 5) < 1e-5)
    }

    @Test("3MF round-trips geometry (write + read via ThreeMF)")
    func threeMF() throws {
        let m = try roundTrip(.threeMF)
        #expect(m.triangleCount == 2)
        let b = try #require(m.bounds)
        #expect(abs(b.max.x - 2) < 1e-4 && abs(b.max.y - 3) < 1e-4 && abs(b.max.z - 5) < 1e-4)
    }

    @Test("GLB round-trips geometry (native write + SwiftGLTF read)")
    func glb() throws {
        let m = try roundTrip(.glb)
        #expect(m.triangleCount == 2)
        let b = try #require(m.bounds)
        #expect(abs(b.max.x - 2) < 1e-4 && abs(b.max.y - 3) < 1e-4 && abs(b.max.z - 5) < 1e-4)
    }

    @Test("glTF round-trips geometry (native write + SwiftGLTF read)")
    func gltf() throws {
        let m = try roundTrip(.gltf)
        #expect(m.triangleCount == 2)
        #expect(abs((m.bounds?.max.z ?? 0) - 5) < 1e-4)
    }

    @Test("format detection + write capability")
    func formats() {
        #expect(MeshFormat(fileExtension: "PLY") == .ply)
        #expect(MeshFormat(fileExtension: "3mf") == .threeMF)
        #expect(MeshFormat(fileExtension: "dwg") == nil)
        #expect(MeshFormat.pmx.canWrite == false)   // source-only
        #expect(MeshFormat.threeMF.canWrite == true)
    }

    /// Builds a minimal valid PMX 2.0 byte buffer for `Self.quad` (2 triangles), split across
    /// `materials` (per-material index-buffer counts, must sum to `indices.count`). Encoding UTF-8,
    /// all index widths 1 byte, no additional UVs, BDEF1 skinning, no textures.
    static func makePMX(materials: [Int]) -> Data {
        var d = Data()
        func u8(_ v: UInt8) { d.append(v) }
        func i32(_ v: Int32) { var x = v; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func f32(_ v: Float) { var x = v; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }

        d.append(contentsOf: [0x50, 0x4D, 0x58, 0x20])        // "PMX "
        f32(2.0)
        u8(8)                                                 // setting count
        u8(1)                                                 // encoding = UTF-8
        u8(0)                                                 // additional UV = 0
        for _ in 0..<6 { u8(1) }                              // index sizes = 1
        for _ in 0..<4 { i32(0) }                             // 4 empty model-info strings

        i32(Int32(quad.positions.count))
        for v in quad.positions {
            f32(v.x); f32(v.y); f32(v.z)                      // position
            f32(0); f32(0); f32(0)                            // normal
            f32(0); f32(0)                                    // uv
            u8(0)                                             // skinning type BDEF1
            u8(0)                                             // bone index (1 byte)
            f32(0)                                            // edge scale
        }

        i32(Int32(quad.indices.count))
        d.append(contentsOf: quad.indices.map { UInt8($0) })

        i32(0)                                                // texture count = 0

        i32(Int32(materials.count))
        for surfaceCount in materials {
            i32(0); i32(0)                                    // name, english name (empty)
            for _ in 0..<11 { f32(0) }                        // diffuse(4) + specular(3) + specularity(1) + ambient(3)
            u8(0)                                              // draw flags
            for _ in 0..<4 { f32(0) }                          // edge color
            f32(0)                                             // edge scale
            u8(0)                                              // texture index (1 byte)
            u8(0)                                              // sphere texture index (1 byte)
            u8(0)                                              // sphere mode
            u8(1)                                              // shared toon flag = internal ref
            u8(0)                                              // toon value (1 byte, internal ref)
            i32(0)                                             // memo (empty)
            i32(Int32(surfaceCount))
        }
        return d
    }

    @Test("PMX submeshes pass through MeshIO.load, one run per material")
    func pmxSubmeshes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mio-submesh.pmx")
        try Self.makePMX(materials: [3, 3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let m = try MeshIO.load(contentsOf: url)
        #expect(m.triangleCount == 2)
        #expect(m.submeshes == [
            Submesh(indexOffset: 0, indexCount: 3, materialIndex: 0),
            Submesh(indexOffset: 3, indexCount: 3, materialIndex: 1),
        ])
        // The invariant worth re-checking downstream of any future welding/filtering: offsets are
        // contiguous and the runs fully cover the index buffer.
        #expect(m.submeshes.reduce(0) { $0 + $1.indexCount } == m.indices.count)
    }

    @Test("non-PMX formats carry no submeshes")
    func noSubmeshesForOtherFormats() throws {
        let m = try roundTrip(.stl)
        #expect(m.submeshes.isEmpty)
    }
}
