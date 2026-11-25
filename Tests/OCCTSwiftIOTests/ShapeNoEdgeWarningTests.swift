import Foundation
import OCCTSwift
import Testing

@testable import OCCTSwiftIO

/// What the shapes path read and made no edge of is said, by type and layer (#91).
///
/// `ShapeLoader` returns a compound of edges. SwiftDXF 0.6.0 reads a `SOLID`, a `WIPEOUT`, a
/// `3DFACE` and a `TOLERANCE` as entities, where 0.5 counted them as skipped (so they were warned
/// about); a `TEXT`, a `DIMENSION`, a `HATCH` and a `LEADER` were never warned about on this path.
/// None of the eight gives an edge, so each is counted in a `.noEdges` warning.
@Suite("Entities with no edges on the shapes path")
struct ShapeNoEdgeWarningTests {

    // MARK: Building drawings

    private static let header = [
        "0", "SECTION", "2", "HEADER", "9", "$INSUNITS", "70", "4", "0", "ENDSEC",
    ]

    private static let line = ["0", "LINE", "8", "0", "10", "0", "20", "0", "11", "5", "21", "0"]

    private static func solid(layer: String) -> [String] {
        [
            "0", "SOLID", "8", layer, "10", "0", "20", "0", "11", "1", "21", "0",
            "12", "1", "22", "1", "13", "0", "23", "1",
        ]
    }

    private static func text(_ entities: [String], blocks: [String] = []) -> String {
        let groups =
            header
            + (blocks.isEmpty ? [] : ["0", "SECTION", "2", "BLOCKS"] + blocks + ["0", "ENDSEC"])
            + ["0", "SECTION", "2", "ENTITIES"] + entities + ["0", "ENDSEC", "0", "EOF"]
        return groups.joined(separator: "\n") + "\n"
    }

    private static func read(_ entities: [String], blocks: [String] = []) throws -> ShapeLoadResult
    {
        let drawing = try DXF.read(
            text: text(entities, blocks: blocks), options: DXFLoader.shapeReadOptions)
        return DXFLoader.shapes(of: drawing, layersKnown: true)
    }

    private static func noEdges(_ result: ShapeLoadResult) -> [DrawingWarning] {
        result.warnings.filter { $0.kind == .noEdges }
    }

    private static func edgeCount(_ result: ShapeLoadResult) -> Int {
        result.shapes.first?.subShapes(ofType: .edge).count ?? 0
    }

    // MARK: The eight types

    @Test("each type with no edge is counted by its DXF name and layer, and gives no edge")
    func eachType() throws {
        let entities =
            Self.line
            + ["0", "TEXT", "8", "NOTES", "10", "1", "20", "1", "40", "2.5", "1", "hello"]
            + ["0", "MTEXT", "8", "NOTES", "10", "2", "20", "1", "40", "2.5", "1", "multi"]
            + [
                "0", "DIMENSION", "8", "DIMS", "70", "0", "10", "10", "20", "0", "13", "0",
                "23", "0", "14", "10", "24", "0", "42", "10",
            ]
            + ["0", "HATCH", "8", "H", "2", "SOLID", "70", "1", "91", "0"]
            + ["0", "LEADER", "8", "LEAD", "10", "0", "20", "0", "10", "5", "20", "5"]
            + ["0", "TOLERANCE", "8", "GDT", "10", "0", "20", "0", "30", "0", "1", "%%v0.1%%v|A"]
            + Self.solid(layer: "FILL")
            + [
                "0", "WIPEOUT", "8", "MASK", "10", "0", "20", "0", "30", "0",
                "11", "1", "21", "0", "31", "0", "12", "0", "22", "1", "32", "0", "13", "1",
                "23", "1",
            ]
            + [
                "0", "3DFACE", "8", "FACE", "10", "0", "20", "0", "30", "0",
                "11", "1", "21", "0", "31", "0", "12", "1", "22", "1", "32", "1",
            ]
        let result = try Self.read(entities)

        // Only the LINE is an edge.
        #expect(Self.edgeCount(result) == 1)
        let found = Self.noEdges(result).map { "\($0.type ?? "-")@\($0.layer ?? "-")x\($0.count)" }
        #expect(
            found == [
                "3DFACE@FACEx1", "DIMENSION@DIMSx1", "HATCH@Hx1", "LEADER@LEADx1",
                "SOLID@FILLx1", "TEXT@NOTESx2", "TOLERANCE@GDTx1", "WIPEOUT@MASKx1",
            ], "\(found)")
        #expect(Self.noEdges(result).allSatisfy { $0.kind == .noEdges })
    }

    @Test("a message names the count, the type and the layer, and says what happened")
    func message() throws {
        let result = try Self.read(
            Self.line + Self.solid(layer: "FILL") + Self.solid(layer: "FILL"))
        let warning = try #require(Self.noEdges(result).first)
        #expect(
            warning.message
                == "2 SOLID entities on layer FILL were read but have no edges, so they are not in the compound"
        )
        #expect(warning.description == warning.message)
    }

    // MARK: Counting

    @Test("the count is by type and by layer, in order")
    func byTypeAndLayer() throws {
        let result = try Self.read(
            Self.solid(layer: "B") + Self.solid(layer: "A") + Self.solid(layer: "B")
                + ["0", "TEXT", "8", "A", "10", "0", "20", "0", "40", "1", "1", "x"])
        let found = Self.noEdges(result).map { "\($0.type ?? "-")@\($0.layer ?? "-")x\($0.count)" }
        #expect(found == ["SOLID@Ax1", "SOLID@Bx2", "TEXT@Ax1"], "\(found)")
    }

    @Test("an entity in a block counts once for each reference")
    func inBlocks() throws {
        let block =
            ["0", "BLOCK", "8", "0", "2", "B", "70", "0", "10", "0", "20", "0"]
            + Self.solid(layer: "FILL")
            + ["0", "LINE", "8", "0", "10", "0", "20", "0", "11", "1", "21", "0"]
            + ["0", "ENDBLK", "8", "0"]
        let result = try Self.read(
            ["0", "INSERT", "8", "0", "2", "B", "10", "0", "20", "0"]
                + ["0", "INSERT", "8", "0", "2", "B", "10", "9", "20", "0"]
                + ["0", "INSERT", "8", "0", "2", "B", "10", "18", "20", "0"],
            blocks: block)
        #expect(Self.edgeCount(result) == 3)
        let solids = Self.noEdges(result)
        #expect(solids.count == 1)
        #expect(solids.first?.type == "SOLID" && solids.first?.layer == "FILL")
        #expect(solids.first?.count == 3)
    }

    @Test("a visible constant attribute of a block is a TEXT with no edge, and is counted")
    func constantAttribute() throws {
        // An ATTDEF with the constant flag (2) is drawn in every reference of its block. SwiftDXF
        // keeps an attribute off the entities unless asked, so the shapes path asks (shapeReadOptions).
        let block =
            ["0", "BLOCK", "8", "0", "2", "TITLE", "70", "0", "10", "0", "20", "0"]
            + [
                "0", "ATTDEF", "8", "TXT", "10", "1", "20", "1", "40", "2", "1", "DRAWING",
                "3", "Prompt", "2", "NAME", "70", "2",
            ]
            + ["0", "ENDBLK", "8", "0"]
        let result = try Self.read(
            ["0", "INSERT", "8", "0", "2", "TITLE", "10", "0", "20", "0"],
            blocks: block)
        let text = Self.noEdges(result).filter { $0.type == "TEXT" }
        #expect(text.count == 1, "\(result.warnings)")
        #expect(text.first?.layer == "TXT" && text.first?.count == 1)
        #expect(!result.warnings.contains { $0.kind == .skippedEntities })
    }

    @Test("a visible attribute a reference carries is counted, an invisible one is not")
    func carriedAttributes() throws {
        // The usual title block: an INSERT of a block with no entities, with its values as ATTRIBs.
        let block =
            ["0", "BLOCK", "8", "0", "2", "TITLE", "70", "0", "10", "0", "20", "0"]
            + ["0", "ENDBLK", "8", "0"]
        let entities = [
            "0", "INSERT", "8", "0", "2", "TITLE", "10", "0", "20", "0", "66", "1",
            "0", "ATTRIB", "8", "SHOWN", "10", "1", "20", "1", "40", "2", "1", "A-101",
            "2", "NUMBER", "70", "0",
            "0", "ATTRIB", "8", "SHOWN", "10", "1", "20", "5", "40", "2", "1", "rev B",
            "2", "REVISION", "70", "0",
            "0", "ATTRIB", "8", "HIDDEN", "10", "1", "20", "9", "40", "2", "1", "secret",
            "2", "NOTE", "70", "1",
            "0", "SEQEND", "8", "0",
        ]
        let result = try Self.read(entities, blocks: block)
        let text = Self.noEdges(result).filter { $0.type == "TEXT" }
        #expect(text.count == 1, "\(result.warnings)")
        #expect(text.first?.layer == "SHOWN" && text.first?.count == 2, "\(result.warnings)")

        // The shapes path read the values as text, so it is not an empty drawing; DrawingLoader,
        // which leaves attributes on their references, finds no entities and says so.
        #expect(!result.warnings.contains { $0.kind == .emptyDrawing })
        let url = try DrawingLoaderTests.temporaryFile(
            "title.dxf", Data(Self.text(entities, blocks: block).utf8))
        let drawing = try DrawingLoader.read(from: url)
        #expect(drawing.warnings.contains { $0.kind == .emptyDrawing }, "\(drawing.warnings)")
    }

    // MARK: What does not warn

    @Test("a drawing of edges alone carries no such warning")
    func edgesAloneAreSilent() throws {
        let result = try Self.read(
            Self.line + ["0", "CIRCLE", "8", "0", "10", "0", "20", "0", "40", "1"]
                + ["0", "ARC", "8", "0", "10", "0", "20", "0", "40", "1", "50", "0", "51", "90"]
                + ["0", "POINT", "8", "0", "10", "3", "20", "3"])
        #expect(result.warnings.isEmpty, "\(result.warnings)")
        #expect(Self.edgeCount(result) == 3)
    }

    @Test("DrawingLoader does not give it: it returns the entities themselves")
    func drawingLoaderIsSilent() throws {
        let groups =
            Self.header + ["0", "SECTION", "2", "ENTITIES"] + Self.line
            + Self.solid(layer: "FILL") + ["0", "ENDSEC", "0", "EOF"]
        let url = try DrawingLoaderTests.temporaryFile(
            "solid.dxf", Data((groups.joined(separator: "\n") + "\n").utf8))
        let result = try DrawingLoader.read(from: url)
        #expect(result.warnings.isEmpty, "\(result.warnings)")
        #expect(result.drawing.entities.count == 2)
    }

    // MARK: Through the loaders

    @Test("ShapeLoader gives it for a DXF")
    func throughShapeLoader() async throws {
        let groups =
            Self.header + ["0", "SECTION", "2", "ENTITIES"] + Self.line
            + Self.solid(layer: "FILL") + ["0", "ENDSEC", "0", "EOF"]
        let url = try DrawingLoaderTests.temporaryFile(
            "withsolid.dxf", Data((groups.joined(separator: "\n") + "\n").utf8))
        let result = try await ShapeLoader.load(from: url, format: .dxf)
        #expect(Self.edgeCount(result) == 1)
        #expect(Self.noEdges(result).map(\.type) == ["SOLID"])
        #expect(Self.noEdges(result).first?.layer == "FILL")
    }

    @Test("a DWG's entities have their layer here though its skipped ones have none")
    func dwgEntitiesHaveLayers() async throws {
        // The AutoCAD DWG with a dimension: its DIMENSION is read, so it has its layer, while
        // DrawingLoader counts what a DWG skipped without one.
        let url = DrawingLoaderTests.autocad("dimassoc-perpendicular.dwg")
        let result = try await ShapeLoader.load(from: url, format: .dwg)
        var expected: [String: Int] = [:]
        for case .dimension(let dimension) in try DrawingLoader.read(from: url).drawing.entities {
            expected[dimension.layer, default: 0] += 1
        }
        var found: [String: Int] = [:]
        for warning in Self.noEdges(result) where warning.type == "DIMENSION" {
            found[warning.layer ?? "(none)"] = warning.count
        }
        #expect(!expected.isEmpty)
        #expect(found == expected, "\(result.warnings)")
    }
}
