import Testing
import Foundation
import OCCTSwift
@testable import OCCTSwiftIO

@Suite("JWW vector loader")
struct JWWLoaderTests {
    /// Loads a real JWW drawing if available locally and checks it maps to a non-empty OCCT compound
    /// whose in-plane (X) extent matches the drawing. (Hermetic synthetic-JWW coverage lives in SwiftJWW.)
    @Test func realDrawingExtent() throws {
        let url = URL(fileURLWithPath: NSString(string: "~/Documents/Modelling/2DFiles/dd12.jww").expandingTildeInPath)
        try withKnownIssue("dd12.jww not present in CI", isIntermittent: true) {
            guard FileManager.default.fileExists(atPath: url.path) else { throw CancellationError() }
            let result = try JWWLoader.load(from: url)
            let shape = try #require(result.shapes.first)
            let b = shape.bounds
            #expect(abs(b.min.x - (-124.59)) < 1.0)     // geometry placed correctly in plane
            #expect(abs(b.max.x - 122.28) < 1.0)
            #expect(b.max.x - b.min.x > 100)            // a real, non-empty drawing
        }
    }

    @Test func formatDetection() {
        #expect(CADFileFormat(fileExtension: "jww") == .jww)
        #expect(CADFileFormat(fileExtension: "JWW") == .jww)
    }
}
