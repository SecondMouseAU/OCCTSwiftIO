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
