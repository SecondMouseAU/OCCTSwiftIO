import Foundation
import OCCTSwift
import Testing

@testable import OCCTSwiftIO

@Suite("DXF contour faces")
struct DXFContourTests {
    /// Fixtures are written by ezdxf (copied from SwiftDXF's tests); areas below are analytic.
    static func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/DXF/\(name).dxf")
    }

    static func area(_ face: DXFContourFace) throws -> Double {
        try #require(face.face.surfaceArea)
    }

    static func near(_ a: Double, _ b: Double, _ tol: Double = 1e-6) -> Bool {
        abs(a - b) <= tol * max(1, abs(b))
    }

    @Test func roundedRectangleKeepsTrueArcs() throws {
        let r = try DXFLoader.loadContours(from: Self.fixture("rounded_rect"))
        let f = try #require(r.faces.first)
        #expect(r.faces.count == 1 && r.unbuilt.isEmpty)
        #expect(Self.near(try Self.area(f), 800 - (4 - Double.pi) * 25))
        #expect(f.face.isFace)
        // 4 lines + 4 arcs, and the arcs are circles rather than polylines.
        let edges = f.face.subShapes(ofType: .edge)
        #expect(edges.count == 8)
        let b = try #require(f.face.bounds)
        #expect(Self.near(b.max.x - b.min.x, 40) && Self.near(b.max.y - b.min.y, 20))
        #expect(abs(b.min.z) < 1e-6 && abs(b.max.z) < 1e-6)
    }

    @Test func plateWithHolesSubtractsHoles() throws {
        let r = try DXFLoader.loadContours(from: Self.fixture("plate_holes"))
        let f = try #require(r.faces.first)
        #expect(r.faces.count == 1)
        #expect(f.holeWires.count == 3)
        #expect(Self.near(try Self.area(f), 6000 - 75 * Double.pi))
        #expect(Self.near(f.area, try Self.area(f)))
    }

    @Test func nestedIslandsBecomeSeparateFaces() throws {
        let r = try DXFLoader.loadContours(from: Self.fixture("nested"))
        #expect(r.faces.count == 2)
        let first = try #require(r.faces.first)
        let last = try #require(r.faces.last)
        #expect(Self.near(try Self.area(first), 3600))
        #expect(Self.near(try Self.area(last), 2000))
        #expect(first.contour.outer.area >= last.contour.outer.area)
        #expect(r.faces.allSatisfy { $0.holeWires.count == 1 })
    }

    @Test func arcsReversedAndOutOfOrderChain() throws {
        let r = try DXFLoader.loadContours(from: Self.fixture("slot_shuffled"))
        let f = try #require(r.faces.first)
        #expect(r.faces.count == 1)
        #expect(Self.near(try Self.area(f), 100 * Double.pi + 400))
        let b = try #require(f.face.bounds)
        #expect(Self.near(b.min.x, -10) && Self.near(b.max.x, 30))
        #expect(Self.near(b.min.y, -10) && Self.near(b.max.y, 10))
    }

    @Test func splineIsFittedAndFaceMatchesContourArea() throws {
        let r = try DXFLoader.loadContours(from: Self.fixture("spline"))
        let f = try #require(r.faces.first)
        #expect(r.unbuilt.isEmpty)
        #expect(r.maxFitDeviation <= 0.01)
        #expect(r.warnings.contains { if case .fittedCurves = $0 { true } else { false } })
        #expect(Self.near(try Self.area(f), f.area, 1e-4))
    }

    @Test func inchUnitsConvertToMillimetres() throws {
        let r = try DXFLoader.loadContours(from: Self.fixture("inch"))
        let f = try #require(r.faces.first)
        #expect(r.unit == .inch && r.unitScale == 25.4)
        #expect(Self.near(try Self.area(f), 50.8 * 50.8))
        let forced = try DXFLoader.loadContours(
            from: Self.fixture("inch"), options: .init(units: .millimetre))
        #expect(Self.near(try Self.area(try #require(forced.faces.first)), 4))
    }

    @Test func layerFilterAndDiagnosticsArePassedThrough() throws {
        let all = try DXFLoader.loadContours(from: Self.fixture("layers"))
        #expect(all.faces.count == 2)
        #expect(all.warnings.contains(.ignoredText(count: 1)))
        let cut = try DXFLoader.loadContours(
            from: Self.fixture("layers"), options: .init(layers: ["cut"]))
        #expect(cut.faces.count == 1)
        #expect(Self.near(try Self.area(try #require(cut.faces.first)), 100))
        #expect(cut.faces.first?.contour.outer.layers == ["CUT"])
    }

    @Test func warningsAndOpenChainsAreData() throws {
        let gap = try DXFLoader.loadContours(from: Self.fixture("gap_beyond"))
        #expect(gap.faces.isEmpty)
        #expect(gap.openChains.count == 1)
        #expect(gap.warnings.contains { if case .openChains(1, _) = $0 { true } else { false } })
        let unitless = try DXFLoader.loadContours(from: Self.fixture("unitless"))
        #expect(unitless.warnings == [.unitlessAssumed(.millimetre)])
        #expect(unitless.shapeLoadResult.shapes.count == 1)
    }

    /// The legacy `load(from:)` is still one compound of curve edges, not faces.
    @Test func legacyLoadStillReturnsEdgeCompound() throws {
        let result = try DXFLoader.load(from: Self.fixture("plate_holes"))
        #expect(result.shapes.count == 1)
        let shape = try #require(result.shapes.first)
        #expect(shape.subShapes(ofType: .face).isEmpty)
        // 4 outline lines + 3 circles
        #expect(shape.subShapes(ofType: .edge).count == 7)
    }

    @Test func legacyLoadFlattensSplines() throws {
        let result = try DXFLoader.load(from: Self.fixture("spline"))
        let shape = try #require(result.shapes.first)
        #expect(shape.subShapes(ofType: .face).isEmpty)
        #expect(shape.subShapes(ofType: .edge).count > 2)
    }
}
