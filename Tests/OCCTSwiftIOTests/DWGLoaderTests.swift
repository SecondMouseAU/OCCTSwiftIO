import Foundation
import Testing

@testable import OCCTSwiftIO

#if canImport(CryptoKit)
    import CryptoKit
#endif

@Suite("DWG loader")
struct DWGLoaderTests {

    /// `plate.dwg`: a 100 x 60 plate with one hole and three DIMENSION entities.
    ///
    /// Written as AC1032 by acadrust from a hand-written DXF. Synthetic, so it carries no
    /// third-party drawing.
    private var plate: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/DWG/plate.dwg")
    }

    @Test func readsGeometryAndDimensions() throws {
        let conversion = try DWGLoader.readEntities(from: plate)

        var lines = 0
        var circles = 0
        var dimensions: [DXF.Dimension] = []
        for entity in conversion.drawing.entities {
            switch entity {
            case .line: lines += 1
            case .circle: circles += 1
            case .dimension(let dimension): dimensions.append(dimension)
            default: break
            }
        }
        #expect(lines == 4)
        #expect(circles == 1)
        #expect(dimensions.count == 3)
        // The typed override survives the read: this is the dimension that says 120 on a plate
        // drawn 100 wide.
        #expect(dimensions.contains { $0.textOverride == "120" })
        #expect(conversion.warnings.isEmpty)
    }

    @Test func anEmptyDrawingIsSaidToBeEmpty() throws {
        let conversion = try DWGLoader.readEntities(
            from: DrawingLoaderTests.autocad("point_object_id.dwg"))
        #expect(conversion.drawing.entities.isEmpty)
        #expect(conversion.warnings == ["the drawing has no entities"])
    }

    @Test func theReadOptionsReachTheDrawing() throws {
        // Five INSERTs, each of a block that holds one attribute definition.
        let url = DrawingLoaderTests.autocad("anonymous-names.dwg")
        let expanded = try DWGLoader.readEntities(from: url, options: .init(expandBlocks: true))
        #expect(expanded.drawing.skipped["ATTDEF"] == 5)
        #expect(expanded.drawing.skipped["INSERT"] == nil)

        let kept = try DWGLoader.readEntities(from: url, options: .init(expandBlocks: false))
        #expect(kept.drawing.skipped["INSERT"] == 5)
        #expect(kept.drawing.references.count == 5)
    }

    @Test func recordsWhatWasRead() throws {
        let conversion = try DWGLoader.readEntities(from: plate)

        #expect(conversion.sourceVersion == "AC1032")
        #expect(conversion.sourceSHA256.count == 64)
        #if canImport(CryptoKit)
            let expected = SHA256.hash(data: try Data(contentsOf: plate))
                .map { String(format: "%02x", $0) }.joined()
            #expect(conversion.sourceSHA256 == expected)
        #endif
    }
}
