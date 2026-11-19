import Foundation
import OCCTSwift
import Testing

@testable import OCCTSwiftIO

/// A JWW reads at full size, with the dimensions SwiftJWW rebuilds from loose pieces (#67).
@Suite("JWW at full size, with rebuilt dimensions")
struct JWWFullSizeTests {

    static func read(_ name: String, _ data: Data) throws -> DrawingResult {
        try DrawingLoader.read(from: try DrawingLoaderTests.temporaryFile(name, data))
    }

    static func dimensions(_ drawing: DXF.Drawing) -> [(index: Int, dimension: DXF.Dimension)] {
        drawing.entities.enumerated().compactMap { index, entity in
            if case .dimension(let dimension) = entity { return (index, dimension) }
            return nil
        }
    }

    @Test("each element is multiplied by its layer group's scale")
    func fullSize() throws {
        let result = try Self.read("plate.jww", JWWFixture.dimensionedPlate())
        // The outline is drawn 10 by 6 at 1:10; the dimension's pieces are in its block.
        #expect(
            DrawingLoaderTests.geometry(result.drawing) == [
                "line [[\"0.0000\", \"0.0000\"], [\"0.0000\", \"60.0000\"]]",
                "line [[\"0.0000\", \"0.0000\"], [\"100.0000\", \"0.0000\"]]",
                "line [[\"0.0000\", \"60.0000\"], [\"100.0000\", \"60.0000\"]]",
                "line [[\"100.0000\", \"0.0000\"], [\"100.0000\", \"60.0000\"]]",
            ])
        #expect(result.layerGroupScales == [.init(group: 0, scale: 10)])
        #expect(!result.warnings.contains { $0.kind == .mixedScales || $0.kind == .scaleNotStated })
    }

    @Test("a dimension kept as loose pieces comes back as a dimension, marked as rebuilt")
    func rebuiltDimension() throws {
        let result = try Self.read("plate.jww", JWWFixture.dimensionedPlate())
        let found = Self.dimensions(result.drawing)
        #expect(found.count == 1)
        guard let (index, dimension) = found.first else { return }
        #expect(dimension.textOverride == "100")
        #expect(dimension.layer == "0-E")
        if let value = dimension.computedMeasurement { #expect(abs(value - 100) < 1e-9) }
        #expect(dimension.computedMeasurement != nil)
        // Its pieces are checked in `JWWRebuiltPiecesTests`.
        #expect(result.rebuiltDimensions.map(\.identity) == [result.drawing.identities[index]])
    }

    @Test("a value no dimension explains is listed at full size, with a warning")
    func unexplainedValue() throws {
        let result = try Self.read("plate.jww", JWWFixture.dimensionedPlate())
        #expect(
            result.unexplainedDimensionValues == [
                .init(text: "R5", position: DXF.Point(30, 30), layer: "0-E")
            ])
        let warnings = result.warnings.filter { $0.kind == .unexplainedDimensionValue }
        #expect(warnings.count == 1)
        #expect(warnings.first?.layer == "0-E")
        #expect(warnings.first?.message.contains("R5") == true)
        // It stays in the drawing as a loose text.
        #expect(
            result.drawing.entities.contains {
                if case .text(_, _, _, let text, _, _) = $0 { return text == "R5" }
                return false
            })
    }

    @Test("groups at different scales are each at full size, with a warning")
    func groupsAtDifferentScales() throws {
        let result = try Self.read("mixed.jww", JWWFixture.mixedScales())
        #expect(
            DrawingLoaderTests.geometry(result.drawing) == [
                "line [[\"0.0000\", \"0.0000\"], [\"100.0000\", \"0.0000\"]]",
                "line [[\"0.0000\", \"1.0000\"], [\"5.0000\", \"1.0000\"]]",
            ])
        #expect(
            result.layerGroupScales == [.init(group: 0, scale: 10), .init(group: 1, scale: 1)])
        let warning = result.warnings.first { $0.kind == .mixedScales }
        #expect(warning?.count == 2)
        #expect(warning?.message.contains("1:10 for group 0") == true)
    }

    @Test("a group that states no scale is read at drawn size, with a warning")
    func groupWithNoScale() throws {
        let result = try Self.read("unstated.jww", JWWFixture.unstatedScale())
        #expect(
            DrawingLoaderTests.geometry(result.drawing) == [
                "line [[\"0.0000\", \"0.0000\"], [\"10.0000\", \"0.0000\"]]"
            ])
        #expect(result.layerGroupScales == [.init(group: 0, scale: 1)])
        #expect(result.warnings.contains { $0.kind == .scaleNotStated && $0.layer == "0-" })
    }

    @Test("a group read at drawn size beside a scaled one is a mixed scale too")
    func unstatedBesideScaled() throws {
        let result = try Self.read("unstated.jww", JWWFixture.scaledBesideUnstated())
        #expect(
            result.layerGroupScales == [.init(group: 0, scale: 10), .init(group: 1, scale: 1)])
        #expect(result.warnings.contains { $0.kind == .scaleNotStated && $0.layer == "1-" })
        let warning = result.warnings.first { $0.kind == .mixedScales }
        #expect(warning?.message.contains("drawn size for group 1") == true)
    }

    @Test("a solid fill SwiftJWW does not read is reported, on both paths")
    func solidFillIsReported() async throws {
        let url = try DrawingLoaderTests.temporaryFile("solid.jww", JWWFixture.solidFill())
        let result = try DrawingLoader.read(from: url)
        #expect(
            result.warnings.contains {
                $0.kind == .skippedEntities && $0.type == "SOLID" && $0.count == 1
                    && $0.layer == nil
            })
        let shapes = try await ShapeLoader.load(from: url, format: .jww)
        #expect(shapes.warnings == result.warnings)
    }

    @Test("a solid fill in a block is reported once, however often the block is placed")
    func solidFillInBlock() throws {
        let result = try Self.read("solid-block.jww", JWWFixture.solidInBlock())
        // The fill at the top level and the one in the block, which is placed twice.
        #expect(
            result.warnings.filter { $0.type == "SOLID" }
                == [
                    DrawingWarning(
                        kind: .skippedEntities, type: "SOLID", count: 2,
                        message: "2 SOLID entities were not read")
                ])
        // The block's line is placed twice, so the placements were expanded.
        #expect(DrawingLoaderTests.geometry(result.drawing).count == 2)
    }

    @Test("a DXF or a DWG has no rebuilt dimensions and no layer group scales")
    func otherFormats() throws {
        for url in [DrawingLoaderTests.plateDXF, DrawingLoaderTests.plateDWG] {
            let result = try DrawingLoader.read(from: url)
            #expect(result.rebuiltDimensions.isEmpty)
            #expect(result.unexplainedDimensionValues.isEmpty)
            #expect(result.layerGroupScales.isEmpty)
        }
    }

    @Test("the shapes path reads a JWW at full size, and says what DrawingLoader says")
    func shapesPath() async throws {
        let url = try DrawingLoaderTests.temporaryFile("plate.jww", JWWFixture.dimensionedPlate())
        let shapes = try await ShapeLoader.load(from: url, format: .jww)
        let drawing = try DrawingLoader.read(from: url)
        #expect(shapes.warnings == drawing.warnings)
        let compound = try #require(shapes.shapes.first)
        let bounds = try #require(compound.bounds)
        #expect(abs(bounds.max.x - bounds.min.x - 100) < 1e-6)
        // The outline's four edges; the dimension's pieces are annotation, in its block.
        #expect(compound.subShapes(ofType: .edge).count == 4)
    }

    @Test("a stored dimension record is a dimension, and is not listed as rebuilt")
    func storedRecord() throws {
        let result = try Self.read("stored.jww", JWWFixture.storedDimension())
        let found = Self.dimensions(result.drawing)
        #expect(found.count == 1)
        let value = found.first?.dimension.computedMeasurement
        #expect(value != nil)
        if let value { #expect(abs(value - 100) < 1e-9) }
        #expect(found.first?.dimension.textOverride == "100")
        #expect(result.rebuiltDimensions.isEmpty)
        #expect(result.unexplainedDimensionValues.isEmpty)
    }

    @Test("a record with no measured points (older than 4.20) is listed and warned about")
    func recordWithoutMeasuredPoints() throws {
        let result = try Self.read("old.jww", JWWFixture.storedDimension(version: 351))
        #expect(result.source.version == "351")
        #expect(Self.dimensions(result.drawing).isEmpty)
        #expect(
            result.unexplainedDimensionValues == [
                .init(text: "100", position: DXF.Point(45, -18), layer: "0-D")
            ])
        #expect(
            result.warnings.contains {
                $0.kind == .unexplainedDimensionValue && $0.message.contains("4.20")
            })
    }

    @Test("a block in a scaled group is placed and expanded at full size, on both paths")
    func blockInScaledGroup() async throws {
        let url = try DrawingLoaderTests.temporaryFile("block.jww", JWWFixture.blockAtScale())
        let result = try DrawingLoader.read(from: url)
        // One drawn unit at 1:10, placed at (2, 3): from (20, 30) to (30, 30).
        #expect(
            DrawingLoaderTests.geometry(result.drawing) == [
                "line [[\"20.0000\", \"30.0000\"], [\"30.0000\", \"30.0000\"]]"
            ])
        let shapes = try await ShapeLoader.load(from: url, format: .jww)
        let compound = try #require(shapes.shapes.first)
        let bounds = try #require(compound.bounds)
        #expect(abs(bounds.min.x - 20) < 1e-6 && abs(bounds.max.x - 30) < 1e-6)
        #expect(shapes.warnings == result.warnings)
    }

    // MARK: real drawings

    /// A drawing on the maintainer's machine.
    ///
    /// The tests that read one are skipped where it is absent, as in CI, and fail as any test
    /// does where it is present.
    static func local(_ name: String) -> URL {
        URL(
            fileURLWithPath: NSString(string: "~/Documents/Modelling/2DFiles/\(name)")
                .expandingTildeInPath)
    }

    static func isLocal(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: local(name).path)
    }

    @Test(
        "the JNR 2120: 29 dimensions rebuilt at 1:80, none unexplained",
        .enabled(if: JWWFullSizeTests.isLocal("2120.jww"), "2120.jww is not in the repository"))
    func the2120() throws {
        let result = try DrawingLoader.read(from: Self.local("2120.jww"))
        let found = Self.dimensions(result.drawing)
        #expect(found.count == 29)
        #expect(result.rebuiltDimensions.count == 29)
        #expect(
            Set(result.rebuiltDimensions.map(\.identity))
                == Set(found.map { result.drawing.identities[$0.index] }))
        #expect(result.unexplainedDimensionValues.isEmpty)
        #expect(result.layerGroupScales == [.init(group: 0, scale: 80)])
        // Each stated value is within one unit of its last digit of the distance drawn. The two
        // `559` dimensions are drawn 558.499 and 558.501 long, so this is not a tighter bound.
        for (_, dimension) in found {
            let label = (dimension.textOverride ?? "").replacingOccurrences(of: ",", with: "")
            guard let stated = Double(label), let measured = dimension.computedMeasurement else {
                Issue.record("no value for \(dimension.textOverride ?? "nil")")
                continue
            }
            #expect(abs(stated - measured) <= 1, "\(label) measures \(measured)")
        }
    }

    @Test(
        "dd12: 14 dimensions rebuilt, and the two values no dimension explains",
        .enabled(if: JWWFullSizeTests.isLocal("dd12.jww"), "dd12.jww is not in the repository"))
    func dd12() throws {
        let result = try DrawingLoader.read(from: Self.local("dd12.jww"))
        #expect(Self.dimensions(result.drawing).count == 14)
        #expect(result.rebuiltDimensions.count == 14)
        #expect(result.unexplainedDimensionValues.map(\.text) == ["5,186.6", "838.2\u{03C6}"])
        #expect(result.warnings.filter { $0.kind == .unexplainedDimensionValue }.count == 2)
        #expect(result.layerGroupScales == [.init(group: 0, scale: 80)])
    }
}
