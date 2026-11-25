import Foundation
import OCCTSwift
import Testing

@testable import OCCTSwiftIO

/// What the shapes path could not make an edge of, though it is drawable, is said (#91).
///
/// Geometry with no size is `.degenerate`; geometry with a size that OCCT would not make an edge of
/// is `.notBuilt`. Before, each was dropped without a word.
@Suite("Dropped geometry on the shapes path")
struct ShapeDroppedWarningTests {

    // MARK: Building drawings

    private static let line = ["0", "LINE", "8", "0", "10", "0", "20", "0", "11", "5", "21", "0"]

    private static func read(_ entities: [String]) throws -> ShapeLoadResult {
        let groups =
            ["0", "SECTION", "2", "HEADER", "9", "$INSUNITS", "70", "4", "0", "ENDSEC"]
            + ["0", "SECTION", "2", "ENTITIES"] + entities + ["0", "ENDSEC", "0", "EOF"]
        let drawing = try DXF.read(
            text: groups.joined(separator: "\n") + "\n", options: DXFLoader.shapeReadOptions)
        return DXFLoader.shapes(of: drawing, layersKnown: true)
    }

    private static func found(_ result: ShapeLoadResult, _ kind: DrawingWarning.Kind) -> [String] {
        result.warnings.filter { $0.kind == kind }.map {
            "\($0.type ?? "-")@\($0.layer ?? "-")x\($0.count)"
        }
    }

    private static func edgeCount(_ result: ShapeLoadResult) -> Int {
        result.shapes.first?.subShapes(ofType: .edge).count ?? 0
    }

    // MARK: Degenerate

    @Test("a line with equal end points, and a circle or arc with no positive radius")
    func linesCirclesAndArcs() throws {
        let result = try Self.read(
            Self.line
                + ["0", "LINE", "8", "L", "10", "1", "20", "1", "11", "1", "21", "1"]
                + ["0", "CIRCLE", "8", "C", "10", "0", "20", "0", "40", "0"]
                + ["0", "CIRCLE", "8", "C", "10", "0", "20", "0", "40", "-1"]
                + ["0", "ARC", "8", "A", "10", "0", "20", "0", "40", "0", "50", "0", "51", "90"])
        #expect(Self.edgeCount(result) == 1, "only the valid line")
        let found = Self.found(result, .degenerate)
        #expect(found == ["ARC@Ax1", "CIRCLE@Cx2", "LINE@Lx1"], "\(found)")
        #expect(Self.found(result, .notBuilt).isEmpty)
    }

    @Test("a polyline with no vertices, and a segment between equal points, which is counted alone")
    func polylines() throws {
        let result = try Self.read(
            Self.line + ["0", "LWPOLYLINE", "8", "P", "90", "0", "70", "0"]
                + [
                    "0", "LWPOLYLINE", "8", "Q", "90", "4", "70", "0",
                    "10", "0", "20", "0", "10", "0", "20", "0", "10", "0", "20", "0",
                    "10", "4", "20", "0",
                ])
        // The valid line, and the one real segment of the second polyline.
        #expect(Self.edgeCount(result) == 2)
        let found = Self.found(result, .degenerate)
        #expect(found == ["POLYLINE@Px1", "POLYLINE@Qx2"], "\(found)")
        let segments = result.warnings.first { $0.layer == "Q" }
        #expect(segments?.message.contains("POLYLINE segments") == true, "\(result.warnings)")
        let empty = result.warnings.first { $0.layer == "P" }
        #expect(empty?.message.contains("POLYLINE entities") == true)
    }

    @Test("a closed polyline that repeats its first vertex is ordinary, and is not counted")
    func closedAndRepeated() throws {
        let result = try Self.read([
            "0", "LWPOLYLINE", "8", "P", "90", "5", "70", "1",
            "10", "0", "20", "0", "10", "4", "20", "0", "10", "4", "20", "3",
            "10", "0", "20", "3", "10", "0", "20", "0",
        ])
        #expect(Self.edgeCount(result) == 4)
        #expect(result.warnings.isEmpty, "\(result.warnings)")
    }

    @Test("end points that differ only in z are the same place on the plane, and are degenerate")
    func differOnlyInZ() throws {
        let result = try Self.read(
            Self.line + [
                "0", "LINE", "8", "Z", "10", "1", "20", "1", "30", "0", "11", "1",
                "21", "1", "31", "5",
            ])
        #expect(Self.edgeCount(result) == 1)
        #expect(Self.found(result, .degenerate) == ["LINE@Zx1"], "\(result.warnings)")
        #expect(Self.found(result, .notBuilt).isEmpty)
    }

    @Test("a polyline of one vertex is a vertex, not a drop")
    func oneVertex() throws {
        let result = try Self.read(
            Self.line + ["0", "LWPOLYLINE", "8", "P", "90", "1", "70", "0", "10", "1", "20", "1"])
        #expect(result.warnings.isEmpty, "\(result.warnings)")
        #expect(result.shapes.first?.subShapes(ofType: .vertex).isEmpty == false)
    }

    @Test("an ellipse and a spline that fit to no lines or arcs")
    func fits() throws {
        let result = try Self.read(
            Self.line
                + [
                    "0", "ELLIPSE", "8", "E", "10", "0", "20", "0", "30", "0", "11", "5", "21", "0",
                    "31", "0", "40", "0", "41", "0", "42", "6.283185307",
                ]
                + [
                    "0", "SPLINE", "8", "S", "70", "8", "71", "3", "72", "8", "73", "4",
                    "40", "0", "40", "0", "40", "0", "40", "0", "40", "1", "40", "1", "40", "1",
                    "40", "1", "10", "2", "20", "2", "10", "2", "20", "2", "10", "2", "20", "2",
                    "10", "2", "20", "2",
                ])
        #expect(Self.edgeCount(result) == 1)
        let found = Self.found(result, .degenerate)
        #expect(found == ["ELLIPSE@Ex1", "SPLINE@Sx1"], "\(found)")
        #expect(result.warnings.contains { $0.message.contains("fitted to lines and arcs") })
    }

    // MARK: Not built

    @Test("a line OCCT will not make an edge of is not built, and is not called degenerate")
    func notBuilt() throws {
        let result = try Self.read(
            Self.line + ["0", "LINE", "8", "L", "10", "inf", "20", "1", "11", "3", "21", "1"])
        #expect(Self.edgeCount(result) == 1)
        #expect(Self.found(result, .notBuilt) == ["LINE@Lx1"], "\(result.warnings)")
        #expect(Self.found(result, .degenerate).isEmpty)
    }

    // MARK: What does not warn

    @Test("a drawing of valid geometry carries none")
    func validIsSilent() throws {
        let result = try Self.read(
            Self.line + ["0", "CIRCLE", "8", "0", "10", "0", "20", "0", "40", "1"]
                + [
                    "0", "ARC", "8", "0", "10", "0", "20", "0", "40", "1", "50", "0", "51", "90",
                    "0", "LWPOLYLINE", "8", "0", "90", "3", "70", "0", "10", "0", "20", "0",
                    "10", "2", "20", "0", "42", "0.5", "10", "4", "20", "3",
                ])
        #expect(result.warnings.isEmpty, "\(result.warnings)")
        #expect(Self.edgeCount(result) == 5)
    }

    @Test("DrawingLoader does not give them: it returns the entities")
    func drawingLoaderIsSilent() throws {
        let groups =
            ["0", "SECTION", "2", "HEADER", "9", "$INSUNITS", "70", "4", "0", "ENDSEC"]
            + ["0", "SECTION", "2", "ENTITIES"] + Self.line
            + ["0", "LINE", "8", "L", "10", "1", "20", "1", "11", "1", "21", "1"]
            + ["0", "ENDSEC", "0", "EOF"]
        let url = try DrawingLoaderTests.temporaryFile(
            "degenerate.dxf", Data((groups.joined(separator: "\n") + "\n").utf8))
        let result = try DrawingLoader.read(from: url)
        #expect(result.warnings.isEmpty, "\(result.warnings)")
        #expect(result.drawing.entities.count == 2)
    }

    @Test("ShapeLoader gives them for a DXF")
    func throughShapeLoader() async throws {
        let groups =
            ["0", "SECTION", "2", "HEADER", "9", "$INSUNITS", "70", "4", "0", "ENDSEC"]
            + ["0", "SECTION", "2", "ENTITIES"] + Self.line
            + ["0", "CIRCLE", "8", "C", "10", "0", "20", "0", "40", "0"]
            + ["0", "ENDSEC", "0", "EOF"]
        let url = try DrawingLoaderTests.temporaryFile(
            "zero.dxf", Data((groups.joined(separator: "\n") + "\n").utf8))
        let result = try await ShapeLoader.load(from: url, format: .dxf)
        #expect(Self.found(result, .degenerate) == ["CIRCLE@Cx1"], "\(result.warnings)")
    }

    // MARK: The compound

    @Test("edges that cannot be joined into a compound are counted, and none is returned")
    func unjoined() throws {
        let edges = try #require(try Self.read(Self.line + Self.line).shapes.first)
            .subShapes(ofType: .edge)
        var tally = DXFLoader.DroppedTally()
        let compound = DXFLoader.joined(edges, counting: &tally, join: { _ in nil })
        #expect(compound == nil)
        let warnings = tally.warnings
        #expect(warnings.count == 1)
        #expect(warnings.first?.kind == .notBuilt && warnings.first?.type == nil)
        #expect(warnings.first?.count == 2, "\(warnings)")

        // Joined, nothing is counted; no edges at all is not a loss of any.
        var fine = DXFLoader.DroppedTally()
        #expect(DXFLoader.joined(edges, counting: &fine) != nil)
        #expect(DXFLoader.joined([], counting: &fine) == nil)
        #expect(fine.warnings.isEmpty)
    }

    // MARK: The tally

    @Test("the tally orders by type, layer and cause, and counts a compound it could not make")
    func tally() {
        var tally = DXFLoader.DroppedTally()
        tally.add(.notBuilt, type: "LINE", layer: "B")
        tally.add(.noLength, type: "LINE", layer: "B")
        tally.add(.noLength, type: "LINE", layer: "A")
        tally.add(.noLength, type: "LINE", layer: "A")
        tally.add(.noLength, type: "POLYLINE", layer: "A", unit: .segments)
        tally.add(.notBuilt, type: "SPLINE", layer: "A", unit: .pieces)
        tally.addUnjoined(3)
        let warnings = tally.warnings
        #expect(
            warnings.map { "\($0.kind.rawValue):\($0.type ?? "-"):\($0.layer ?? "-"):\($0.count)" }
                == [
                    "degenerate:LINE:A:2", "degenerate:LINE:B:1", "notBuilt:LINE:B:1",
                    "degenerate:POLYLINE:A:1", "notBuilt:SPLINE:A:1", "notBuilt:-:-:3",
                ])
        #expect(
            warnings[4].message
                == "1 SPLINE pieces on layer A gave no edge, as OCCT would not make one, "
                + "so they are not in the compound")
        #expect(
            warnings[0].message
                == "2 LINE entities on layer A have no length, so they are not in the compound")
        #expect(
            warnings.last?.message
                == "3 edges were made but OCCT could not join them into a compound, so none is returned"
        )
    }
}
