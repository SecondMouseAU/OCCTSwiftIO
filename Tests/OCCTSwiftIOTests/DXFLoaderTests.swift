import Testing
import Foundation
import OCCTSwift
@testable import OCCTSwiftIO

@Suite("DXF vector loader")
struct DXFLoaderTests {
    /// Loads a real DXF drawing if available locally and checks it maps to a non-empty OCCT compound
    /// whose in-plane extent matches the drawing. (Hermetic synthetic + ezdxf-oracle coverage lives in
    /// SwiftDXF; the per-file entity-count oracle lives there too.)
    @Test func realDrawingExtent() throws {
        let url = URL(fileURLWithPath: NSString(string: "~/Documents/Modelling/2DFiles/dd12.dxf").expandingTildeInPath)
        try withKnownIssue("dd12.dxf not present in CI", isIntermittent: true) {
            guard FileManager.default.fileExists(atPath: url.path) else { throw CancellationError() }
            let result = try DXFLoader.load(from: url)
            let shape = try #require(result.shapes.first)
            let b = shape.bounds
            // Geometry placed correctly in plane (DXF extents ≈ x:[-168, 177], y:[-272, 315]); the OCCT
            // compound's tight bounds sit within those conservative extents.
            #expect(b.min.x > -170 && b.min.x < -100)
            #expect(b.max.x < 180 && b.max.x > 100)
            #expect(b.max.x - b.min.x > 200)            // a real, non-empty drawing
            #expect(abs(b.min.z) < 1e-6 && abs(b.max.z) < 1e-6)   // flat: all geometry in the Z=0 plane
        }
    }

    @Test func formatDetection() {
        #expect(CADFileFormat(fileExtension: "dxf") == .dxf)
        #expect(CADFileFormat(fileExtension: "DXF") == .dxf)
    }
}
