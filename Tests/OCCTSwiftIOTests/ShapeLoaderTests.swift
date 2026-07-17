import Testing
import Foundation
import simd
import OCCTSwift
@testable import OCCTSwiftIO

@Suite("ShapeLoader")
struct ShapeLoaderTests {

    private static func tempURL(suffix: String) -> URL {
        URL(fileURLWithPath: "/tmp/occtswiftio-loader-\(UUID().uuidString)-\(suffix)")
    }

    @Test func t_formatRecognition() {
        #expect(CADFileFormat(fileExtension: "step") == .step)
        #expect(CADFileFormat(fileExtension: "STEP") == .step)
        #expect(CADFileFormat(fileExtension: "stp") == .step)
        #expect(CADFileFormat(fileExtension: "stl") == .stl)
        #expect(CADFileFormat(fileExtension: "obj") == .obj)
        #expect(CADFileFormat(fileExtension: "brep") == .brep)
        #expect(CADFileFormat(fileExtension: "BREP") == .brep)
        #expect(CADFileFormat(fileExtension: "brp") == .brep)
        #expect(CADFileFormat(fileExtension: "iges") == .iges)
        #expect(CADFileFormat(fileExtension: "IGES") == .iges)
        #expect(CADFileFormat(fileExtension: "igs") == .iges)
        #expect(CADFileFormat(fileExtension: "xyz") == nil)
    }

    @Test func t_stepRoundTripProducesShapes() async throws {
        guard let box = Shape.box(width: 5, height: 3, depth: 2) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let url = Self.tempURL(suffix: "box.step")
        defer { try? FileManager.default.removeItem(at: url) }

        try await ExportManager.export(shapes: [box], format: .step, to: url)
        let result = try await ShapeLoader.load(from: url, format: .step)

        #expect(result.shapes.count >= 1, "STEP round-trip should produce at least one shape")
        // No GD&T metadata for a plain box export — just verifying the fields
        // exist and default to empty.
        #expect(result.dimensions.isEmpty)
        #expect(result.geomTolerances.isEmpty)
        #expect(result.datums.isEmpty)
    }

    @Test func t_brepRoundTripProducesOneShape() async throws {
        guard let box = Shape.box(width: 1, height: 1, depth: 1) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let url = Self.tempURL(suffix: "box.brep")
        defer { try? FileManager.default.removeItem(at: url) }

        try await ExportManager.export(shapes: [box], format: .brep, to: url)
        let result = try await ShapeLoader.load(from: url, format: .brep)

        #expect(result.shapesWithColors.count == 1, "BREP carries one shape")
        #expect(result.shapesWithColors[0].color == nil, "BREP has no color")
    }

    // Two spatially separated unit boxes, as one compound shape.
    private static func twoBodyCompound() -> Shape? {
        guard let a = Shape.box(origin: SIMD3<Double>(0, 0, 0), width: 1, height: 1, depth: 1),
              let b = Shape.box(origin: SIMD3<Double>(5, 0, 0), width: 1, height: 1, depth: 1) else {
            return nil
        }
        return Shape.compound([a, b])
    }

    // #21: a multibody BREP must come back as one entry per body, not one lumped
    // entry. BREP is exact (no meshing/sewing), so the count is deterministic.
    @Test func t_brepMultibodySplitsIntoPerBodyEntries() async throws {
        guard let compound = Self.twoBodyCompound() else {
            Issue.record("failed to build two-body compound"); return
        }
        let url = Self.tempURL(suffix: "twobody.brep")
        defer { try? FileManager.default.removeItem(at: url) }

        // shapes: [compound] hits ExportManager's single-file branch, so this is
        // one BREP holding a compound of two solids — not two numbered files.
        try await ExportManager.export(shapes: [compound], format: .brep, to: url)
        let result = try await ShapeLoader.load(from: url, format: .brep)

        #expect(result.shapesWithColors.count == 2,
                "two-body BREP should split into two entries, got \(result.shapesWithColors.count)")
        #expect(result.shapesWithColors.allSatisfy { $0.shape.shapeType == .solid },
                "each entry should be a single solid, not the compound")
    }

    // #21: the issue's actual path — robust STL of a multibody file. Since
    // OCCTSwift v1.11.3 this returns a compound of solids (SecondMouseAU/OCCTSwift#302);
    // the loader must split it. Meshing/sewing makes the exact count less certain
    // than BREP, so assert the property under test: more than one body entry.
    @Test func t_stlRobustMultibodySplitsIntoPerBodyEntries() async throws {
        guard let compound = Self.twoBodyCompound() else {
            Issue.record("failed to build two-body compound"); return
        }
        let url = Self.tempURL(suffix: "twobody.stl")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeSTL(shape: compound, to: url)
        let result = try await ShapeLoader.loadRobust(from: url, format: .stl)

        #expect(result.shapesWithColors.count >= 2,
                "robust STL of a two-body file should split, got \(result.shapesWithColors.count)")
    }

    // Regression guard on the fallback: a shape with no solids (a raw-mesh STL
    // comes back as loose faces) must stay a single entry, never collapse to zero.
    @Test func t_nonRobustStlStaysOneEntry() async throws {
        guard let box = Shape.box(width: 2, height: 2, depth: 2) else {
            Issue.record("Shape.box returned nil"); return
        }
        let url = Self.tempURL(suffix: "one.stl")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeSTL(shape: box, to: url)
        let result = try await ShapeLoader.load(from: url, format: .stl)

        #expect(result.shapesWithColors.count == 1,
                "a non-robust single-body STL stays one entry, got \(result.shapesWithColors.count)")
    }

    @Test func t_loadFromManifestSkipsMissingFiles() throws {
        // Temp dir with manifest only — no body files. Loader should skip the
        // descriptor (file missing) and return empty shapesWithColors.
        let tempDir = URL(fileURLWithPath: "/tmp/occtswiftio-manifest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manifestJSON = """
        {
          "version": 1,
          "timestamp": "2026-05-06T12:00:00Z",
          "bodies": [
            { "id": "missing", "file": "does-not-exist.brep", "format": "brep" }
          ]
        }
        """
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try manifestJSON.write(to: manifestURL, atomically: true, encoding: .utf8)

        let result = try ShapeLoader.loadFromManifest(at: manifestURL)
        #expect(result.shapesWithColors.isEmpty, "missing body file should be skipped")
        #expect(result.manifest != nil, "manifest itself should still decode")
        #expect(result.manifest?.bodies.count == 1)
    }
}
