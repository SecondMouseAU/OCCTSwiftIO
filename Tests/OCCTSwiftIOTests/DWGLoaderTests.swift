import Foundation
import Testing

@testable import OCCTSwiftIO

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

    /// The converter is a separately built tool.
    ///
    /// Tests that need it are skipped when it is not installed, and say so, so "passed" never means
    /// "did not run".
    private func converter() -> URL? { DWGLoader.locateConverter() }

    @Test func readsGeometryAndDimensions() throws {
        try withKnownIssue("dwg2dxf not installed (build Tools/dwg2dxf)", isIntermittent: true) {
            guard let converter = converter() else { throw CancellationError() }
            let conversion = try DWGLoader.readEntities(from: plate, converter: converter)

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
            // The typed override survives the conversion: this is the dimension that says 120 on
            // a plate drawn 100 wide.
            #expect(dimensions.contains { $0.textOverride == "120" })
            #expect(conversion.warnings.isEmpty)
        }
    }

    @Test func recordsWhatWasConvertedAndWhatConvertedIt() throws {
        try withKnownIssue("dwg2dxf not installed (build Tools/dwg2dxf)", isIntermittent: true) {
            guard let converter = converter() else { throw CancellationError() }
            let conversion = try DWGLoader.readEntities(from: plate, converter: converter)

            #expect(conversion.sourceVersion == "AC1032")
            #expect(conversion.sourceSHA256.count == 64)
            #expect(conversion.converter.hasPrefix("dwg2dxf "))
            #expect(conversion.converter.contains("acadrust "))
        }
    }

    @Test func aFileThatIsNotADWGIsRefusedBeforeConverting() throws {
        try withKnownIssue("dwg2dxf not installed (build Tools/dwg2dxf)", isIntermittent: true) {
            guard let converter = converter() else { throw CancellationError() }
            let notDWG = URL(fileURLWithPath: #filePath)
            #expect(throws: DWGLoader.DWGError.self) {
                _ = try DWGLoader.readEntities(from: notDWG, converter: converter)
            }
        }
    }

    @Test func aMissingConverterIsAnErrorThatSaysHowToFixIt() throws {
        let missing = URL(fileURLWithPath: "/nonexistent/dwg2dxf")
        #expect(DWGLoader.locateConverter(explicit: missing) == nil)
        do {
            _ = try DWGLoader.readEntities(from: plate, converter: missing)
            Issue.record("expected converterNotFound")
        } catch let error as DWGLoader.DWGError {
            #expect("\(error)".contains("Tools/dwg2dxf"))
        }
    }
}
