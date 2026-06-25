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

    /// The #11 primary deliverable: the entity model (TEXT strings + per-entity layers) reachable
    /// through the OCCTSwiftIO import surface, not just the lossy Shape compound.
    @Test func entityLevelReadKeepsTextAndLayers() throws {
        let url = URL(fileURLWithPath: NSString(string: "~/Documents/Modelling/2DFiles/dd12.dxf").expandingTildeInPath)
        try withKnownIssue("dd12.dxf not present in CI", isIntermittent: true) {
            guard FileManager.default.fileExists(atPath: url.path) else { throw CancellationError() }
            let dwg = try DXFLoader.readEntities(from: url)        // DXF.* in scope via OCCTSwiftIO
            var texts: [String] = []
            var layers = Set<String>()
            for e in dwg.entities {
                switch e {
                case let .text(_, _, _, s, layer, _): texts.append(s); layers.insert(layer)
                case let .line(_, _, layer, _): layers.insert(layer)
                case let .arc(_, _, _, _, layer, _): layers.insert(layer)
                case let .circle(_, _, layer, _): layers.insert(layer)
                default: break
                }
            }
            #expect(texts.count > 10)                              // TEXT entities preserved...
            #expect(texts.allSatisfy { !$0.isEmpty })             // ...with their (CP932-decoded) strings
            #expect(layers.count > 1)                             // entities span multiple layers
        }
    }

    /// A bulged LWPOLYLINE segment becomes a real arc edge (ezdxf convention: bulge 1 over a
    /// (0,0)→(2,0) chord is a CCW semicircle dipping to apex (1,−1)).
    @Test func bulgePolylineBecomesArc() throws {
        let dxf = """
        0
        SECTION
        2
        ENTITIES
        0
        LWPOLYLINE
        90
        2
        70
        0
        10
        0.0
        20
        0.0
        42
        1.0
        10
        2.0
        20
        0.0
        0
        ENDSEC
        0
        EOF
        """
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("bulge-\(UUID().uuidString).dxf")
        try dxf.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try DXFLoader.load(from: tmp)
        let shape = try #require(result.shapes.first)
        let b = shape.bounds
        #expect(abs(b.min.x) < 1e-6 && abs(b.max.x - 2) < 1e-6)   // chord endpoints
        #expect(b.min.y < -0.99 && b.min.y > -1.01)               // semicircle apex at y = −1
        #expect(abs(b.max.y) < 1e-6)                              // arc stays on/below the chord
    }

    @Test func formatDetection() {
        #expect(CADFileFormat(fileExtension: "dxf") == .dxf)
        #expect(CADFileFormat(fileExtension: "DXF") == .dxf)
    }
}
