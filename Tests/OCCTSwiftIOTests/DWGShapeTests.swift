import Foundation
import OCCTSwift
import Testing

@testable import OCCTSwiftIO

/// `ShapeLoader` loads a DWG as one compound of edges, the way it loads a DXF (#58).
@Suite("DWG as shapes")
struct DWGShapeTests {

    @Test("the extension dwg is recognised in any case")
    func formatRecognition() {
        #expect(CADFileFormat(fileExtension: "dwg") == .dwg)
        #expect(CADFileFormat(fileExtension: "DWG") == .dwg)
    }

    @Test("a DWG loads as one compound of edges")
    func loadsAsEdges() async throws {
        let result = try await ShapeLoader.load(from: DrawingLoaderTests.plateDWG, format: .dwg)
        #expect(result.shapesWithColors.count == 1)
        let shape = try #require(result.shapes.first)
        #expect(shape.shapeType == .compound)
        // A 100 x 60 plate: four lines for the outline and one circle for the hole. The three
        // dimensions on the sheet have no edges.
        #expect(shape.subShapes(ofType: .edge).count == 5)
    }

    @Test("the same plate from a DWG and a DXF is the same compound of edges")
    func sameAsTheDXF() async throws {
        let dwg = try await ShapeLoader.load(from: DrawingLoaderTests.plateDWG, format: .dwg)
        let dxf = try await ShapeLoader.load(from: DrawingLoaderTests.plateDXF, format: .dxf)
        let fromDWG = try #require(dwg.shapes.first)
        let fromDXF = try #require(dxf.shapes.first)

        #expect(fromDWG.subShapes(ofType: .edge).count == fromDXF.subShapes(ofType: .edge).count)
        let a = try #require(fromDWG.bounds)
        let b = try #require(fromDXF.bounds)
        let fromDWGBox = [a.min.x, a.min.y, a.max.x, a.max.y]
        let fromDXFBox = [b.min.x, b.min.y, b.max.x, b.max.y]
        for (x, y) in zip(fromDWGBox, fromDXFBox) { #expect(abs(x - y) < 1e-6) }
        #expect(abs((a.max.x - a.min.x) - 100) < 1e-3, "the plate is 100 wide")
    }

    @Test("a robust load of a DWG is the same load")
    func robustIsTheSame() async throws {
        let result = try await ShapeLoader.loadRobust(
            from: DrawingLoaderTests.plateDWG, format: .dwg)
        #expect(try #require(result.shapes.first).subShapes(ofType: .edge).count == 5)
    }

    @Test("a file that is not a DWG throws DWG.Error")
    func notADWG() async throws {
        let url = try DrawingLoaderTests.temporaryFile("not.dwg", Data("hello, not a drawing".utf8))
        await #expect(throws: DWG.Error.self) {
            _ = try await ShapeLoader.load(from: url, format: .dwg)
        }
    }

    @Test("a truncated DWG throws DWG.Error, not a crash")
    func truncated() async throws {
        let whole = try Data(contentsOf: DrawingLoaderTests.plateDWG)
        let url = try DrawingLoaderTests.temporaryFile("cut.dwg", whole.prefix(whole.count / 2))
        await #expect(throws: DWG.Error.self) {
            _ = try await ShapeLoader.load(from: url, format: .dwg)
        }
    }
}
