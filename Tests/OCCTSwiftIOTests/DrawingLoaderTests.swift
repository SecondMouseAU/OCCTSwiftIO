import Foundation
import Testing

@testable import OCCTSwiftIO

#if canImport(CryptoKit)
    import CryptoKit
#endif

@Suite("Drawing loader")
struct DrawingLoaderTests {

    static var fixtures: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    static var plateDXF: URL { fixtures.appendingPathComponent("Drawing/plate.dxf") }
    static var plateDWG: URL { fixtures.appendingPathComponent("DWG/plate.dwg") }

    /// Writes bytes to a file with the given name in a fresh temporary directory.
    static func temporaryFile(_ name: String, _ data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("drawing-loader-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    /// The lines and circles of a drawing as comparable strings, in any order.
    static func geometry(_ drawing: DXF.Drawing) -> [String] {
        func f(_ v: Double) -> String { String(format: "%.4f", v) }
        var out: [String] = []
        for entity in drawing.entities {
            switch entity {
            case .line(let a, let b, _, _):
                let ends = [[f(a.x), f(a.y)], [f(b.x), f(b.y)]].sorted {
                    $0.lexicographicallyPrecedes($1)
                }
                out.append("line \(ends)")
            case .circle(let c, let r, _, _):
                out.append("circle \(f(c.x)) \(f(c.y)) \(f(r))")
            default:
                break
            }
        }
        return out.sorted()
    }

    // MARK: format

    @Test("the format comes from the bytes, not the extension")
    func sniffing() throws {
        let dxf = try Data(contentsOf: Self.plateDXF)
        #expect(DrawingFormat.sniff(dxf) == .dxf)
        #expect(DrawingFormat.sniff(dxf, fileExtension: "dwg") == .dxf)
        #expect(DrawingFormat.sniff(try Data(contentsOf: Self.plateDWG)) == .dwg)
        #expect(DrawingFormat.sniff(JWWFixture.plate(), fileExtension: "dxf") == .jww)
        #expect(DrawingFormat.sniff(Data("not a drawing".utf8)) == nil)
        #expect(DrawingFormat.sniff(Data("not a drawing".utf8), fileExtension: "DXF") == .dxf)
    }

    @Test("an unrecognised file is an error")
    func unrecognised() throws {
        let url = try Self.temporaryFile("notes.txt", Data("hello".utf8))
        #expect(throws: DrawingLoader.LoadError.self) { try DrawingLoader.read(from: url) }
    }

    // MARK: DXF

    @Test("a DXF is read with its source record")
    func dxfSource() throws {
        let result = try DrawingLoader.read(from: Self.plateDXF)
        #expect(result.source.fileName == "plate.dxf")
        #expect(result.source.format == .dxf)
        #expect(result.source.version == "AC1032")
        #expect(result.source.converter == nil)
        #if canImport(CryptoKit)
            let expected = SHA256.hash(data: try Data(contentsOf: Self.plateDXF))
                .map { String(format: "%02x", $0) }.joined()
            #expect(result.source.sha256 == expected)
        #endif
        #expect(result.drawing.entities.count == 5)
        #expect(result.drawing.insUnits == 4)
        #expect(result.drawing.identities.map(\.id) == ["#31", "#32", "#33", "#34", "#35"])
        #expect(result.warnings.isEmpty)
    }

    // MARK: JWW

    @Test("a JWW is read into the same model")
    func jwwSource() throws {
        let url = try Self.temporaryFile("plate.jww", JWWFixture.plate())
        let result = try DrawingLoader.read(from: url)
        #expect(result.source.format == .jww && result.source.version == "700")
        #expect(result.source.converter == nil)
        #expect(result.drawing.entities.count == 5)
        #expect(result.drawing.counts.line == 4 && result.drawing.counts.circle == 1)
        // JWW declares no length unit, which a consumer must be told rather than assume.
        #expect(result.warnings.contains { $0.kind == .unitsNotDeclared })
    }

    // MARK: the same plate from three formats

    @Test("the same plate from a DXF and a JWW has the same entities")
    func dxfAndJWW() throws {
        let dxf = try DrawingLoader.read(from: Self.plateDXF)
        let jww = try DrawingLoader.read(
            from: try Self.temporaryFile("plate.jww", JWWFixture.plate()))
        #expect(Self.geometry(dxf.drawing) == Self.geometry(jww.drawing))
        #expect(Self.geometry(dxf.drawing).count == 5)
    }

    @Test("the same plate from a DXF, a DWG and a JWW has the same entities")
    func dxfDWGAndJWW() throws {
        try withKnownIssue("dwg2dxf not installed (build Tools/dwg2dxf)", isIntermittent: true) {
            guard DWGLoader.locateConverter() != nil else { throw CancellationError() }
            let dxf = try DrawingLoader.read(from: Self.plateDXF)
            let dwg = try DrawingLoader.read(from: Self.plateDWG)
            let jww = try DrawingLoader.read(
                from: try Self.temporaryFile("plate.jww", JWWFixture.plate()))
            #expect(dwg.source.format == .dwg && dwg.source.version == "AC1032")
            #expect(dwg.source.converter?.hasPrefix("dwg2dxf") == true)
            #expect(Self.geometry(dwg.drawing) == Self.geometry(dxf.drawing))
            #expect(Self.geometry(jww.drawing) == Self.geometry(dwg.drawing))
            // The DWG also carries the three dimensions the JWW cannot.
            #expect(dwg.drawing.counts.dimension == 3)
        }
    }

    @Test("a DWG keeps its handles, so the same entity has the same identity")
    func dwgHandles() throws {
        try withKnownIssue("dwg2dxf not installed (build Tools/dwg2dxf)", isIntermittent: true) {
            guard DWGLoader.locateConverter() != nil else { throw CancellationError() }
            let first = try DrawingLoader.read(from: Self.plateDWG)
            let second = try DrawingLoader.read(from: Self.plateDWG)
            #expect(first.drawing.identities == second.drawing.identities)
            #expect(first.drawing.identities.allSatisfy { $0.handle != nil })
            let dxf = try DrawingLoader.read(from: Self.plateDXF)
            #expect(first.drawing.identities.prefix(5) == dxf.drawing.identities.prefix(5))
        }
    }

    // MARK: warnings

    @Test("skipped entities are reported by type and layer, and hatches and leaders are not lost")
    func skippedWarnings() throws {
        let dxf = """
            0
            SECTION
            2
            HEADER
            9
            $INSUNITS
            70
            4
            0
            ENDSEC
            0
            SECTION
            2
            ENTITIES
            0
            SOLID
            8
            FILL
            10
            0
            20
            0
            0
            SOLID
            8
            FILL
            10
            1
            20
            1
            0
            HATCH
            8
            H
            2
            SOLID
            70
            1
            91
            0
            0
            LINE
            8
            0
            10
            0
            20
            0
            11
            1
            21
            1
            0
            ENDSEC
            0
            EOF
            """
        let url = try Self.temporaryFile("mixed.dxf", Data(dxf.utf8))
        let result = try DrawingLoader.read(from: url)
        let skipped = result.warnings.filter { $0.kind == .skippedEntities }
        #expect(skipped.count == 1)
        #expect(skipped.first?.type == "SOLID" && skipped.first?.layer == "FILL")
        #expect(skipped.first?.count == 2)
        #expect(result.drawing.hatches.count == 1)
        #expect(!result.warnings.contains { $0.type == "HATCH" })
        #expect(!result.warnings.contains { $0.kind == .unitsNotDeclared })
    }

    @Test("block references are expanded by default, with the reference in each identity")
    func blocksExpanded() throws {
        let dxf = """
            0
            SECTION
            2
            HEADER
            9
            $INSUNITS
            70
            4
            0
            ENDSEC
            0
            SECTION
            2
            BLOCKS
            0
            BLOCK
            2
            TAG
            10
            0
            20
            0
            0
            LINE
            5
            C1
            8
            0
            10
            0
            20
            0
            11
            2
            21
            0
            0
            ENDBLK
            0
            ENDSEC
            0
            SECTION
            2
            ENTITIES
            0
            INSERT
            5
            A1
            8
            0
            2
            TAG
            10
            10
            20
            5
            0
            INSERT
            5
            A2
            8
            0
            2
            MISSING
            10
            0
            20
            0
            0
            ENDSEC
            0
            EOF
            """
        let url = try Self.temporaryFile("blocks.dxf", Data(dxf.utf8))
        let expanded = try DrawingLoader.read(from: url)
        #expect(expanded.drawing.entities.count == 1)
        #expect(expanded.drawing.identities.first?.id == "#A1/#C1")
        #expect(expanded.drawing.identities.first?.blocks == ["TAG"])
        #expect(expanded.warnings.contains { $0.kind == .missingBlock && $0.type == "MISSING" })

        let flat = try DrawingLoader.read(from: url, options: .init(expandBlocks: false))
        #expect(flat.drawing.entities.isEmpty)
        #expect(flat.warnings.contains { $0.kind == .skippedEntities && $0.type == "INSERT" })
    }

    @Test("an empty drawing is said to be empty")
    func emptyDrawing() throws {
        let url = try Self.temporaryFile(
            "empty.dxf", Data("0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF\n".utf8))
        let result = try DrawingLoader.read(from: url)
        #expect(result.warnings.contains { $0.kind == .emptyDrawing })
    }
}
