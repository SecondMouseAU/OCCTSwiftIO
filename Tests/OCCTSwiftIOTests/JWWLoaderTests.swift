import Foundation
import OCCTSwift
import Testing

@testable import OCCTSwiftIO

@Suite("JWW vector loader")
struct JWWLoaderTests {
    static let dd12 = URL(
        fileURLWithPath: NSString(string: "~/Documents/Modelling/2DFiles/dd12.jww")
            .expandingTildeInPath)

    /// Loads a real JWW drawing, where it is on this machine, and checks it maps to a non-empty
    /// OCCT compound whose in-plane (X) extent matches the drawing at full size.
    ///
    /// dd12 is drawn at 1:80, so the extent is 80 times its extent on the sheet (-124.59 to
    /// 122.28). Skipped where the file is absent, as in CI; synthetic JWW coverage is in
    /// `JWWFullSizeTests` and in SwiftJWW.
    @Test(
        .enabled(
            if: FileManager.default.fileExists(atPath: JWWLoaderTests.dd12.path),
            "dd12.jww is only on the maintainer's machine"))
    func realDrawingExtent() throws {
        let result = try JWWLoader.load(from: Self.dd12)
        let shape = try #require(result.shapes.first)
        // #require, not a default: since OCCTSwift 3.0.0 a nil here means OCCT reported a void
        // bounding box, which has to fail the assertion rather than read as a zero-size drawing.
        let b = try #require(shape.bounds)
        #expect(abs(b.min.x - (-124.59 * 80)) < 80)  // placed correctly in plane, at full size
        #expect(abs(b.max.x - 122.28 * 80) < 80)
        #expect(b.max.x - b.min.x > 100 * 80)  // a real, non-empty drawing
    }

    @Test func formatDetection() {
        #expect(CADFileFormat(fileExtension: "jww") == .jww)
        #expect(CADFileFormat(fileExtension: "JWW") == .jww)
    }
}
