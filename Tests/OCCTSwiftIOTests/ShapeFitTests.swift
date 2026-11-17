import Foundation
import OCCTSwift
import Testing
import simd

@testable import OCCTSwiftIO

/// A DXF or DWG spline or ellipse comes through `ShapeLoader` as lines and circular arcs within a
/// tolerance, not as straight chords (#75).
///
/// Before, a spline was flattened to chords and an ellipse to a fixed 48 of them. On an ellipse of
/// major radius 1000 and ratio 0.2, those 48 chords strayed 2 units from the curve, ten times the
/// tolerance (one ten-thousandth of the drawing's diagonal) a spline was flattened to.
@Suite("Splines and ellipses on the shapes path")
struct ShapeFitTests {

    // MARK: Building drawings

    private static func drawing(_ entities: [String]) throws -> DXF.Drawing {
        let groups = ["0", "SECTION", "2", "ENTITIES"] + entities + ["0", "ENDSEC", "0", "EOF"]
        return try DXF.read(
            text: groups.joined(separator: "\n") + "\n", options: DXFLoader.shapeReadOptions)
    }

    private static func ellipse(
        center: SIMD2<Double>, major: SIMD2<Double>, ratio: Double,
        start: Double = 0, end: Double = 2 * .pi
    ) -> [String] {
        [
            "0", "ELLIPSE", "8", "0",
            "10", "\(center.x)", "20", "\(center.y)", "30", "0",
            "11", "\(major.x)", "21", "\(major.y)", "31", "0",
            "40", "\(ratio)", "41", "\(start)", "42", "\(end)",
        ]
    }

    private static func spline(
        degree: Int, knots: [Double], weights: [Double] = [], points: [SIMD2<Double>]
    ) -> [String] {
        // 8 is planar, 4 is rational.
        var groups = [
            "0", "SPLINE", "8", "0", "70", weights.isEmpty ? "8" : "12", "71", "\(degree)",
            "72", "\(knots.count)", "73", "\(points.count)", "74", "0",
        ]
        for k in knots { groups += ["40", "\(k)"] }
        for w in weights { groups += ["41", "\(w)"] }
        for p in points { groups += ["10", "\(p.x)", "20", "\(p.y)", "30", "0"] }
        return groups
    }

    // MARK: Measuring

    /// The edges `ShapeLoader` builds for a drawing.
    private static func edges(of drawing: DXF.Drawing) -> [Edge] {
        guard let shape = DXFLoader.shapes(of: drawing, layersKnown: true).shapes.first else {
            return []
        }
        return shape.subShapes(ofType: .edge).compactMap { Edge($0) }
    }

    /// The tolerance the shapes path fits to: one ten-thousandth of the drawing's diagonal.
    private static func tolerance(of drawing: DXF.Drawing) -> Double {
        guard let b = drawing.bounds else { return 1e-6 }
        let dx = b.max.x - b.min.x
        let dy = b.max.y - b.min.y
        return max((dx * dx + dy * dy).squareRoot() * 1e-4, 1e-9)
    }

    /// Points along each edge, end to end.
    private static func samples(of edges: [Edge], perEdge: Int = 24) -> [SIMD2<Double>] {
        var points: [SIMD2<Double>] = []
        for edge in edges {
            guard let range = edge.parameterBounds else { continue }
            for i in 0...perEdge {
                let t = range.first + (range.last - range.first) * Double(i) / Double(perEdge)
                if let p = edge.point(at: t) { points.append(SIMD2(p.x, p.y)) }
            }
        }
        return points
    }

    private static func distance(
        from p: SIMD2<Double>, toSegment a: SIMD2<Double>, _ b: SIMD2<Double>
    ) -> Double {
        let ab = b - a
        let lengthSquared = ab.x * ab.x + ab.y * ab.y
        let dot = (p.x - a.x) * ab.x + (p.y - a.y) * ab.y
        let along = lengthSquared > 0 ? dot / lengthSquared : 0
        let nearest = a + ab * max(0, min(1, along))
        let d = p - nearest
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The largest distance from a point on any edge to a densely sampled reference curve.
    private static func farthest(_ edges: [Edge], from reference: [SIMD2<Double>]) -> Double {
        var worst = 0.0
        for p in samples(of: edges) {
            var nearest = Double.infinity
            for i in 0..<(reference.count - 1) {
                nearest = min(nearest, distance(from: p, toSegment: reference[i], reference[i + 1]))
            }
            worst = max(worst, nearest)
        }
        return worst
    }

    /// The ellipse with the given centre and major-axis end, as a dense polyline over `[t0, t1]`.
    private static func ellipseReference(
        center: SIMD2<Double>, major: SIMD2<Double>, ratio: Double, from t0: Double, to t1: Double
    ) -> [SIMD2<Double>] {
        let minor = SIMD2(-major.y, major.x) * ratio
        return (0...20_000).map { i in
            let t = t0 + (t1 - t0) * Double(i) / 20_000
            return center + major * cos(t) + minor * sin(t)
        }
    }

    // MARK: Ellipses

    @Test("a circle drawn as an ellipse is two arcs, not a ring of chords")
    func circleEllipse() throws {
        let drawing = try Self.drawing(
            Self.ellipse(center: SIMD2(20, 30), major: SIMD2(50, 0), ratio: 1))
        let edges = Self.edges(of: drawing)
        // An arc never sweeps more than a half turn, so a full circle is two.
        #expect(edges.count == 2)
        #expect(edges.allSatisfy { $0.isCircle }, "every edge is a circular arc")
        let reference = Self.ellipseReference(
            center: SIMD2(20, 30), major: SIMD2(50, 0), ratio: 1, from: 0, to: 2 * .pi)
        #expect(Self.farthest(edges, from: reference) < 1e-6, "it is the circle itself")
    }

    @Test("a tilted ellipse is within the tolerance, in fewer edges than 48 chords")
    func tiltedEllipse() throws {
        let center = SIMD2(5.0, -12.0)
        let major = SIMD2(60.0, 35.0)
        let drawing = try Self.drawing(Self.ellipse(center: center, major: major, ratio: 0.3))
        let edges = Self.edges(of: drawing)
        let tolerance = Self.tolerance(of: drawing)
        #expect(!edges.isEmpty)
        #expect(edges.count < 48, "\(edges.count) edges; the chords were a fixed 48")
        #expect(edges.allSatisfy { $0.isLine || $0.isCircle }, "lines and arcs only")
        let reference = Self.ellipseReference(
            center: center, major: major, ratio: 0.3, from: 0, to: 2 * .pi)
        let worst = Self.farthest(edges, from: reference)
        #expect(worst <= tolerance, "strays \(worst) from the curve; tolerance is \(tolerance)")
    }

    @Test("an elliptical arc keeps its two ends")
    func ellipticalArc() throws {
        let center = SIMD2(0.0, 0.0)
        let major = SIMD2(80.0, 20.0)
        let (t0, t1) = (0.5, 2.0)
        let drawing = try Self.drawing(
            Self.ellipse(center: center, major: major, ratio: 0.4, start: t0, end: t1))
        let edges = Self.edges(of: drawing)
        #expect(!edges.isEmpty)
        let reference = Self.ellipseReference(
            center: center, major: major, ratio: 0.4, from: t0, to: t1)
        #expect(Self.farthest(edges, from: reference) <= Self.tolerance(of: drawing))
        // The arc runs from the point at `t0` to the point at `t1`, and no further.
        let ends = edges.flatMap { [$0.endpoints.start, $0.endpoints.end] }
            .map { SIMD2($0.x, $0.y) }
        for want in [reference[0], reference[reference.count - 1]] {
            let nearest = ends.map { simd_length($0 - want) }.min() ?? .infinity
            #expect(nearest < 1e-6, "no edge ends at \(want)")
        }
    }

    @Test("an ellipse with no major axis is left out, not drawn")
    func degenerateEllipse() throws {
        let line = ["0", "LINE", "8", "0", "10", "0", "20", "0", "11", "10", "21", "0"]
        let drawing = try Self.drawing(
            line + Self.ellipse(center: SIMD2(5, 5), major: SIMD2(0, 0), ratio: 0.5))
        #expect(Self.edges(of: drawing).count == 1, "only the line")
    }

    // MARK: Splines

    @Test("a spline that is a straight line is one line edge")
    func lineSpline() throws {
        let drawing = try Self.drawing(
            Self.spline(
                degree: 3, knots: [0, 0, 0, 0, 1, 1, 1, 1],
                points: [SIMD2(0, 0), SIMD2(10, 5), SIMD2(20, 10), SIMD2(30, 15)]))
        let edges = Self.edges(of: drawing)
        #expect(edges.count == 1)
        if let edge = edges.first {
            #expect(edge.isLine)
            #expect(abs(edge.length - (30.0 * 30.0 + 15.0 * 15.0).squareRoot()) < 1e-6)
        }
    }

    @Test("a spline that is a circular arc is one arc edge")
    func arcSpline() throws {
        // A quarter circle of radius 50 about the origin, as a rational quadratic.
        let drawing = try Self.drawing(
            Self.spline(
                degree: 2, knots: [0, 0, 0, 1, 1, 1], weights: [1, 0.5.squareRoot(), 1],
                points: [SIMD2(50, 0), SIMD2(50, 50), SIMD2(0, 50)]))
        let edges = Self.edges(of: drawing)
        #expect(edges.count == 1)
        if let edge = edges.first {
            #expect(edge.isCircle)
            #expect(abs(edge.length - 50 * Double.pi / 2) < 1e-6)
        }
    }

    @Test("a smooth spline is within the tolerance, in fewer edges than chords")
    func smoothSpline() throws {
        // A cubic Bezier S-curve, and its points by de Casteljau.
        let p: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(30, 80), SIMD2(70, -80), SIMD2(100, 0)]
        let drawing = try Self.drawing(
            Self.spline(degree: 3, knots: [0, 0, 0, 0, 1, 1, 1, 1], points: p))
        let edges = Self.edges(of: drawing)
        let tolerance = Self.tolerance(of: drawing)
        let reference: [SIMD2<Double>] = (0...20_000).map { i in
            let t = Double(i) / 20_000
            let a = p[0] + (p[1] - p[0]) * t
            let b = p[1] + (p[2] - p[1]) * t
            let c = p[2] + (p[3] - p[2]) * t
            let d = a + (b - a) * t
            let e = b + (c - b) * t
            return d + (e - d) * t
        }
        let worst = Self.farthest(edges, from: reference)
        #expect(worst <= tolerance, "strays \(worst) from the curve; tolerance is \(tolerance)")
        #expect(edges.contains { $0.isCircle }, "arcs, not only lines")
        var chords = 0
        for case .spline(let spline) in drawing.entities {
            chords += spline.flattened(tolerance: tolerance).count - 1
        }
        #expect(edges.count < chords, "\(edges.count) edges against \(chords) chords")
    }

    @Test("the repo's spline fixture loads as lines and arcs within the tolerance")
    func fixtureSpline() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/DXF/spline.dxf")
        let drawing = try DXF.read(contentsOf: url, options: DXFLoader.shapeReadOptions)
        let edges = Self.edges(of: drawing)
        let tolerance = Self.tolerance(of: drawing)
        #expect(edges.allSatisfy { $0.isLine || $0.isCircle })
        // The same curve, flattened far finer than the tolerance, is the reference.
        var reference: [SIMD2<Double>] = []
        for case .spline(let spline) in drawing.entities {
            reference = spline.flattened(tolerance: tolerance / 1_000).map { SIMD2($0.x, $0.y) }
        }
        let curveEdges = edges.filter { $0.isCircle }
        #expect(!curveEdges.isEmpty)
        #expect(reference.count > 2)
        #expect(Self.farthest(curveEdges, from: reference) <= tolerance)
    }
}
