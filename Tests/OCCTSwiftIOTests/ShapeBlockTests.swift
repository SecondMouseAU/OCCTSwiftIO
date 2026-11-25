import Foundation
import OCCTSwift
import Testing

@testable import OCCTSwiftIO

/// `ShapeLoader` expands block references on a DXF or a DWG and reports what it left out (#70).
///
/// Before, the geometry inside an `INSERT` was not in the compound and the result had nowhere to
/// say so: a drawing whose lines sit in blocks came back looking complete and nearly empty.
@Suite("Block references on the shapes path")
struct ShapeBlockTests {

    /// A DXF group-code stream, one value per line.
    private static func dxf(_ groups: [String]) -> Data {
        Data((groups.joined(separator: "\n") + "\n").utf8)
    }

    private static let header = [
        "0", "SECTION", "2", "HEADER", "9", "$INSUNITS", "70", "4", "0", "ENDSEC",
    ]

    /// A block `TAG` of two lines and a circle (three edges), inserted three times 100 apart, beside
    /// one line outside any block.
    private static let framed: [String] =
        header + [
            "0", "SECTION", "2", "BLOCKS",
            "0", "BLOCK", "2", "TAG", "10", "0", "20", "0",
            "0", "LINE", "8", "0", "10", "0", "20", "0", "11", "10", "21", "0",
            "0", "LINE", "8", "0", "10", "10", "20", "0", "11", "10", "21", "10",
            "0", "CIRCLE", "8", "0", "10", "5", "20", "5", "40", "2",
            "0", "ENDBLK",
            "0", "ENDSEC",
            "0", "SECTION", "2", "ENTITIES",
            "0", "LINE", "8", "0", "10", "0", "20", "-20", "11", "5", "21", "-20",
            "0", "INSERT", "8", "0", "2", "TAG", "10", "0", "20", "0",
            "0", "INSERT", "8", "0", "2", "TAG", "10", "100", "20", "0",
            "0", "INSERT", "8", "0", "2", "TAG", "10", "200", "20", "0",
            "0", "ENDSEC", "0", "EOF",
        ]

    private static func load(_ data: Data, as name: String, format: CADFileFormat) async throws
        -> ShapeLoadResult
    {
        let url = try DrawingLoaderTests.temporaryFile(name, data)
        return try await ShapeLoader.load(from: url, format: format)
    }

    @Test("the geometry inside a block reference is in the compound")
    func blockGeometryIsLoaded() async throws {
        let result = try await Self.load(Self.dxf(Self.framed), as: "framed.dxf", format: .dxf)
        let shape = try #require(result.shapes.first)
        // One line outside the block, and three edges in each of three references.
        #expect(shape.subShapes(ofType: .edge).count == 1 + 3 * 3)
        // The references are placed where they were put: the third one reaches x = 200 + 10.
        let box = try #require(shape.bounds)
        #expect(abs(box.min.x - 0) < 1e-6)
        #expect(abs(box.max.x - 210) < 1e-6)
        #expect(result.warnings.isEmpty, "nothing was left out: \(result.warnings)")
    }

    @Test("a block that cannot be expanded is reported, not dropped without a word")
    func missingBlockIsReported() async throws {
        let data = Self.dxf(
            Self.header + [
                "0", "SECTION", "2", "ENTITIES",
                "0", "LINE", "8", "0", "10", "0", "20", "0", "11", "5", "21", "0",
                "0", "INSERT", "8", "0", "2", "GONE", "10", "0", "20", "0",
                "0", "INSERT", "8", "0", "2", "GONE", "10", "9", "20", "0",
                "0", "ENDSEC", "0", "EOF",
            ])
        let result = try await Self.load(data, as: "missing.dxf", format: .dxf)
        #expect(try #require(result.shapes.first).subShapes(ofType: .edge).count == 1)
        let missing = result.warnings.filter { $0.kind == .missingBlock }
        #expect(missing.count == 1)
        #expect(missing.first?.type == "GONE")
        #expect(missing.first?.count == 2)
    }

    @Test("an entity with no entity form is reported by type and layer")
    func skippedEntityIsReported() async throws {
        let data = Self.dxf(
            Self.header + [
                "0", "SECTION", "2", "ENTITIES",
                "0", "LINE", "8", "0", "10", "0", "20", "0", "11", "5", "21", "0",
                // MLINE is a type SwiftDXF does not model; SOLID was one until SwiftDXF 0.6.0 (#91).
                "0", "MLINE", "8", "HATCHING", "10", "0", "20", "0", "11", "1", "21", "0",
                "12", "1", "22", "1", "13", "0", "23", "1",
                "0", "ENDSEC", "0", "EOF",
            ])
        let result = try await Self.load(data, as: "skipped.dxf", format: .dxf)
        let skipped = result.warnings.filter { $0.kind == .skippedEntities }
        #expect(skipped.count == 1)
        #expect(skipped.first?.type == "MLINE")
        #expect(skipped.first?.layer == "HATCHING")
    }

    @Test("an empty drawing is reported on the shapes path too")
    func emptyDrawingIsReported() async throws {
        let result = try await Self.load(
            Self.dxf(Self.header + ["0", "SECTION", "2", "ENTITIES", "0", "ENDSEC", "0", "EOF"]),
            as: "empty.dxf", format: .dxf)
        #expect(result.shapes.isEmpty)
        #expect(result.warnings.contains { $0.kind == .emptyDrawing })
    }

    @Test("the shapes path says what DrawingLoader says, and more: what it made no edge of")
    func sameWarningsAsDrawingLoader() async throws {
        let blocks = try DrawingLoaderTests.temporaryFile("framed.dxf", Self.dxf(Self.framed))
        let files: [(URL, CADFileFormat)] = [
            (blocks, .dxf),
            (DrawingLoaderTests.plateDXF, .dxf),
            (DrawingLoaderTests.plateDWG, .dwg),
            (DrawingLoaderTests.autocad("anonymous-names.dwg"), .dwg),
            (DrawingLoaderTests.autocad("point_object_id.dwg"), .dwg),
            (try DrawingLoaderTests.temporaryFile("plate.jww", JWWFixture.plate()), .jww),
            (
                try DrawingLoaderTests.temporaryFile(
                    "dimensioned.jww", JWWFixture.dimensionedPlate()), .jww
            ),
            (try DrawingLoaderTests.temporaryFile("mixed.jww", JWWFixture.mixedScales()), .jww),
        ]
        for (url, format) in files {
            let shapes = try await ShapeLoader.load(from: url, format: format)
            let drawing = try DrawingLoader.read(from: url)
            // `.noEdges` is the one kind only the shapes path gives (ShapeNoEdgeWarningTests).
            #expect(
                shapes.warnings.filter { $0.kind != .noEdges } == drawing.warnings,
                "\(url.lastPathComponent) disagrees")
            #expect(!drawing.warnings.contains { $0.kind == .noEdges })
        }
    }

    @Test("a DWG's block references are expanded, and an attribute definition is not skipped (#91)")
    func dwgBlocksAreExpanded() async throws {
        // Five INSERTs, each of a block that holds one attribute definition: no edges, but the
        // references are placed, so no INSERT is left over. SwiftDXF 0.5 counted the five ATTDEFs
        // as skipped; 0.6.0 keeps a definition on its block (#91), where it is not drawn unless it
        // is constant, so there is nothing to count.
        let result = try await ShapeLoader.load(
            from: DrawingLoaderTests.autocad("anonymous-names.dwg"), format: .dwg)
        #expect(!result.warnings.contains { $0.kind == .skippedEntities })
        #expect(!result.warnings.contains { $0.type == "INSERT" })
    }

    @Test("a robust load of a drawing is the same load")
    func robustIsTheSame() async throws {
        let url = try DrawingLoaderTests.temporaryFile("framed.dxf", Self.dxf(Self.framed))
        let result = try await ShapeLoader.loadRobust(from: url, format: .dxf)
        #expect(try #require(result.shapes.first).subShapes(ofType: .edge).count == 10)
    }

    @Test("formats with no such notion carry no warnings")
    func otherFormatsHaveNone() throws {
        #expect(ShapeLoadResult().warnings.isEmpty)
    }
}
