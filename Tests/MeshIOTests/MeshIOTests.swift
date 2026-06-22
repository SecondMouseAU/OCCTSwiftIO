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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mio.\(fmt.rawValue)")
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

    @Test("format detection + write capability")
    func formats() {
        #expect(MeshFormat(fileExtension: "PLY") == .ply)
        #expect(MeshFormat(fileExtension: "3mf") == .threeMF)
        #expect(MeshFormat(fileExtension: "dwg") == nil)
        #expect(MeshFormat.pmx.canWrite == false)   // source-only
        #expect(MeshFormat.threeMF.canWrite == true)
    }
}
