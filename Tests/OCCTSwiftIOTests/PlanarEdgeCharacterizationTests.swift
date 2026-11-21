import Foundation
import OCCTSwift
import Testing
import simd

@testable import OCCTSwiftIO

/// What the shapes path (DXF, DWG, JWW) and the contour path build, held edge for edge (#30).
///
/// Each case pins how many edges, in what order, of what kind (line, circle or other), with three
/// points on each (start, middle and end, at its parameter bounds) and its length. Those fix an
/// arc's centre, radius, sweep and direction. Written against the loaders before their planar
/// edge construction moved to `PlanarEdge`, and run unchanged after. A JWW is read through
/// SwiftJWW's DXF writer and then takes the DXF path.
@Suite("Planar edges, pinned edge for edge")
struct PlanarEdgeCharacterizationTests {

    // MARK: What is held

    enum Kind: String { case line, circle, other }

    struct Facts {
        var kind: Kind
        var start: SIMD3<Double>
        var mid: SIMD3<Double>
        var end: SIMD3<Double>
        var length: Double
    }

    /// An edge's facts, with every point at z = 0.
    static func fact(
        _ kind: Kind, _ sx: Double, _ sy: Double, _ mx: Double, _ my: Double, _ ex: Double,
        _ ey: Double, _ length: Double
    ) -> Facts {
        Facts(
            kind: kind, start: SIMD3(sx, sy, 0), mid: SIMD3(mx, my, 0), end: SIMD3(ex, ey, 0),
            length: length)
    }

    static func facts(of edge: Edge) -> Facts? {
        guard let range = edge.parameterBounds,
            let start = edge.point(at: range.first),
            let mid = edge.point(at: (range.first + range.last) / 2),
            let end = edge.point(at: range.last)
        else { return nil }
        let kind: Kind = edge.isLine ? .line : edge.isCircle ? .circle : .other
        return Facts(kind: kind, start: start, mid: mid, end: end, length: edge.length)
    }

    static func check(
        _ got: [Facts], _ want: [Facts], tolerance: Double = 1e-8,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(got.count == want.count, "edge count", sourceLocation: sourceLocation)
        for (i, (g, w)) in zip(got, want).enumerated() {
            #expect(g.kind == w.kind, "edge \(i) kind", sourceLocation: sourceLocation)
            #expect(
                simd_distance(g.start, w.start) < tolerance, "edge \(i) start \(g.start)",
                sourceLocation: sourceLocation)
            #expect(
                simd_distance(g.mid, w.mid) < tolerance, "edge \(i) middle \(g.mid)",
                sourceLocation: sourceLocation)
            #expect(
                simd_distance(g.end, w.end) < tolerance, "edge \(i) end \(g.end)",
                sourceLocation: sourceLocation)
            #expect(
                abs(g.length - w.length) < tolerance, "edge \(i) length \(g.length)",
                sourceLocation: sourceLocation)
        }
    }

    /// A long run of edges (an ellipse fitted to arcs), held by its count, the sums of its lengths
    /// and of all its sampled points, which move if any one edge does, and a few edges in full.
    static func checkRun(
        _ got: [Facts], count: Int, lengthSum: Double, pointSum: SIMD3<Double>,
        samples: [(index: Int, facts: Facts)], tolerance: Double = 1e-7,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(got.count == count, "edge count", sourceLocation: sourceLocation)
        #expect(
            abs(got.reduce(0) { $0 + $1.length } - lengthSum) < tolerance, "sum of lengths",
            sourceLocation: sourceLocation)
        let points = got.reduce(SIMD3<Double>.zero) { $0 + $1.start + $1.mid + $1.end }
        #expect(
            simd_distance(points, pointSum) < tolerance, "sum of points \(points)",
            sourceLocation: sourceLocation)
        for sample in samples where got.indices.contains(sample.index) {
            check([got[sample.index]], [sample.facts], sourceLocation: sourceLocation)
        }
    }

    // MARK: Building drawings

    static func dxf(_ entities: [[String]]) throws -> DXF.Drawing {
        let groups =
            ["0", "SECTION", "2", "ENTITIES"] + entities.flatMap { $0 } + [
                "0", "ENDSEC", "0", "EOF",
            ]
        return try DXF.read(
            text: groups.joined(separator: "\n") + "\n", options: DXFLoader.shapeReadOptions)
    }

    static func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> [String] {
        [
            "0", "LINE", "8", "0", "10", "\(x1)", "20", "\(y1)", "30", "0", "11", "\(x2)", "21",
            "\(y2)",
            "31", "0",
        ]
    }

    static func circle(_ x: Double, _ y: Double, _ r: Double) -> [String] {
        ["0", "CIRCLE", "8", "0", "10", "\(x)", "20", "\(y)", "30", "0", "40", "\(r)"]
    }

    static func arc(
        _ x: Double, _ y: Double, _ r: Double, from start: Double, to end: Double
    ) -> [String] {
        [
            "0", "ARC", "8", "0", "10", "\(x)", "20", "\(y)", "30", "0", "40", "\(r)", "50",
            "\(start)",
            "51", "\(end)",
        ]
    }

    static func point(_ x: Double, _ y: Double) -> [String] {
        ["0", "POINT", "8", "0", "10", "\(x)", "20", "\(y)", "30", "0"]
    }

    /// An LWPOLYLINE; each vertex is x, y and the bulge of the segment that leaves it.
    static func polyline(_ vertices: [(Double, Double, Double)], closed: Bool) -> [String] {
        var groups = [
            "0", "LWPOLYLINE", "8", "0", "90", "\(vertices.count)", "70", closed ? "1" : "0",
        ]
        for v in vertices {
            groups += ["10", "\(v.0)", "20", "\(v.1)"]
            if v.2 != 0 { groups += ["42", "\(v.2)"] }
        }
        return groups
    }

    static func ellipse(
        center: SIMD2<Double>, major: SIMD2<Double>, ratio: Double, start: Double = 0,
        end: Double = 2 * .pi
    ) -> [String] {
        [
            "0", "ELLIPSE", "8", "0",
            "10", "\(center.x)", "20", "\(center.y)", "30", "0",
            "11", "\(major.x)", "21", "\(major.y)", "31", "0",
            "40", "\(ratio)", "41", "\(start)", "42", "\(end)",
        ]
    }

    /// The edges of the one compound `DXFLoader` builds for the entities, in compound order.
    static func dxfEdges(_ entities: [[String]]) throws -> [Facts] {
        try edges(of: DXFLoader.shapes(of: dxf(entities), layersKnown: true))
    }

    static func edges(of result: ShapeLoadResult) -> [Facts] {
        guard let shape = result.shapes.first else { return [] }
        return shape.subShapes(ofType: .edge).compactMap { Edge($0) }.compactMap(facts(of:))
    }

    // MARK: JWW

    /// A v700 JWW of `objects` entities, as `write` writes them.
    static func jww(objects: Int, _ write: (inout JWWFixture.Builder) -> Void) -> Data {
        var b = JWWFixture.Builder()
        b.header()
        b.u16(objects)
        write(&b)
        return b.d
    }

    static func jwwLine(
        _ b: inout JWWFixture.Builder, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double
    ) {
        b.objectTag("CDataSen")
        b.base()
        b.f64(x1)
        b.f64(y1)
        b.f64(x2)
        b.f64(y2)
    }

    /// A CDataEnko: a circle, an arc, an ellipse or an elliptical arc, by `ratio` and `full`.
    static func jwwEnko(
        _ b: inout JWWFixture.Builder, center: (Double, Double), radius: Double,
        start: Double = 0, sweep: Double = 2 * .pi, tilt: Double = 0, ratio: Double = 1,
        full: Bool
    ) {
        b.objectTag("CDataEnko")
        b.base()
        b.f64(center.0)
        b.f64(center.1)
        b.f64(radius)
        b.f64(start)
        b.f64(sweep)
        b.f64(tilt)
        b.f64(ratio)
        b.u32(full ? 1 : 0)
    }

    static func jwwEdges(_ data: Data) throws -> [Facts] {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "edges-\(UUID().uuidString).jww")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return edges(of: try JWWLoader.load(from: url))
    }

    // MARK: Contours

    static func contourEdges(_ result: DXFContourResult) -> [[Facts]] {
        result.faces.map { face in
            ([face.outerWire] + face.holeWires).flatMap { wire in
                wire.edges().compactMap { facts(of: $0) }
            }
        }
    }

    static func segmentEdge(_ segment: DXF.Contour.Segment) -> Facts? {
        guard let shape = DXFLoader.edge(for: segment), let edge = Edge(shape) else { return nil }
        return facts(of: edge)
    }

    // MARK: DXF, the shapes path

    /// Two lines, and a line from a point to itself, which is left out.
    @Test func t_dxfLines() throws {
        Self.check(
            try Self.dxfLines(),
            [
                Self.fact(.line, 0.0, 0.0, 1.5, 2.0, 3.0, 4.0, 5.0),
                Self.fact(.line, -2.0, 1.0, 2.0, 1.0, 6.0, 1.0, 8.0),
            ])
    }

    /// A circle is one full-circle edge; a circle of radius 0 is left out.
    @Test func t_dxfCircles() throws {
        Self.check(
            try Self.dxfCircles(),
            [
                Self.fact(.circle, 15.0, 20.0, 5.0, 20.0, 15.0, 20.0, 31.4159265359)
            ])
    }

    /// Arcs run counter-clockwise: through angle 0 when the end is before the start, a full turn
    /// when equal.
    @Test func t_dxfArcs() throws {
        Self.check(
            try Self.dxfArcs(),
            [
                Self.fact(
                    .circle, 3.59807621135, 3.5, 1.77645713531, 4.89777747887, -0.5, 4.59807621135,
                    4.71238898038),
                Self.fact(
                    .circle, -3.0, -1.73205080757, -2.0, 0.0, -3.0, 1.73205080757, 4.18879020479),
                Self.fact(.circle, 0.0, 4.0, 0.0, -4.0, 0.0, 4.0, 25.1327412287),
            ])
    }

    /// A bulged segment is a circular arc; a segment between coincident vertices is left out.
    @Test func t_dxfPolylines() throws {
        Self.check(
            try Self.dxfPolylines(),
            [
                Self.fact(.line, 0.0, 0.0, 2.0, 0.0, 4.0, 0.0, 4.0),
                Self.fact(.circle, 4.0, 0.0, 4.75, 1.5, 4.0, 3.0, 3.47735706751),
                Self.fact(.line, 4.0, 3.0, 2.0, 1.5, 0.0, 0.0, 5.0),
                Self.fact(.line, 10.0, 0.0, 11.0, 1.0, 12.0, 2.0, 2.82842712475),
            ])
    }

    /// A bulge of 1 is a semicircle; -2 is a clockwise arc of more than a half turn.
    @Test func t_dxfBulges() throws {
        Self.check(
            try Self.dxfBulges(),
            [
                Self.fact(.circle, 0.0, 0.0, 1.0, -1.0, 2.0, 0.0, 3.14159265359),
                Self.fact(.circle, 13.0, 1.0, 10.5, 3.5, 10.0, 0.0, 8.75277914191),
            ])
    }

    /// A POINT, and a polyline of one vertex, are vertices.
    @Test func t_dxfVertices() throws {
        let vertices = try Self.dxfVertices()
        #expect(vertices.count == 2)
        if vertices.indices.contains(0) {
            #expect(simd_distance(vertices[0], SIMD3(3.0, 4.0, 0.0)) < 1e-6)
        }
        if vertices.indices.contains(1) {
            #expect(simd_distance(vertices[1], SIMD3(20.0, 20.0, 0.0)) < 1e-6)
        }
    }

    /// A circle drawn as an ellipse is two half-turn arcs.
    @Test func t_dxfEllipseAsCircle() throws {
        Self.check(
            try Self.dxfEllipseCircle(),
            [
                Self.fact(.circle, 70.0, 30.0, 20.0, 80.0, -30.0, 30.0, 157.079632679),
                Self.fact(.circle, -30.0, 30.0, 20.0, -20.0, 70.0, 30.0, 157.079632679),
            ])
    }

    /// A tilted full ellipse, fitted to arcs.
    @Test func t_dxfEllipseFull() throws {
        Self.checkRun(
            try Self.dxfEllipseFull(), count: 27, lengthSum: 304.654990787,
            pointSum: SIMD3(312.68548221, -1015.40622005, 0.0),
            samples: [
                (
                    0,
                    Self.fact(
                        .circle, -55.0, -47.0, -53.8832857311, -48.4136351853, -52.4407997565,
                        -49.492824422, 3.6131674512)
                ),
                (
                    13,
                    Self.fact(
                        .circle, 65.5166504987, 21.8721993097, 64.5686390615, 23.6446525346,
                        63.125170285, 25.0434784748, 4.0362457165)
                ),
                (
                    26,
                    Self.fact(
                        .circle, -55.8207340555, -44.6254212839, -55.5229061475, -45.8516079367,
                        -55.0, -47.0, 2.52743645725)
                ),
            ])
    }

    /// Elliptical arcs, one through its parameter 0, fitted to arcs.
    @Test func t_dxfEllipseArcs() throws {
        Self.checkRun(
            try Self.dxfEllipseArcs(), count: 12, lengthSum: 93.0527387602,
            pointSum: SIMD3(3059.6890102, 352.473034192, 0.0),
            samples: [
                (
                    0,
                    Self.fact(
                        .circle, 23.9303491637, 15.967208698, 21.1567035014, 16.9574924732,
                        18.2793428557, 17.5856388978, 5.89427624023)
                ),
                (
                    6,
                    Self.fact(
                        .circle, 126.844641275, -1.19759369859, 128.427870447, 1.06968501862,
                        129.649806819, 3.55041855851, 5.53602284582)
                ),
                (
                    11,
                    Self.fact(
                        .circle, 118.895246358, 17.4783648732, 115.461694387, 17.9183403506,
                        112.001714252, 18.0250878308, 6.92594564401)
                ),
            ])
    }

    /// A line and a circle; a line from a point to itself is left out.
    @Test func t_jwwLineAndCircle() throws {
        Self.check(
            try Self.jwwLineAndCircle(),
            [
                Self.fact(.line, 0.0, 0.0, 1.5, 2.0, 3.0, 4.0, 5.0),
                Self.fact(.circle, 15.0, 20.0, 5.0, 20.0, 15.0, 20.0, 31.4159265359),
            ])
    }

    /// Circular arcs: an ordinary one, one through angle 0, and a clockwise one.
    @Test func t_jwwArcs() throws {
        Self.check(
            try Self.jwwArcs(),
            [
                Self.fact(
                    .circle, 3.63274767956, 3.438276627, 1.94596708179, 4.84695385986,
                    -0.248440508396, 4.72789228105, 4.49999998588),
                Self.fact(
                    .circle, -2.58266045935, -1.41108065911, -2.04682474603, 0.430239964755,
                    -3.30672935293, 1.87599994934, 3.99999999909),
                Self.fact(
                    .circle, 10.0806045974, 7.3170580212, 11.0, 9.0, 10.0806045974, 10.6829419788,
                    4.00000003399),
            ])
    }

    /// A full ellipse, fitted to arcs.
    @Test func t_jwwEllipseFull() throws {
        Self.checkRun(
            try Self.jwwEllipseFull(), count: 25, lengthSum: 276.158750095,
            pointSum: SIMD3(493.087923289, -851.56338088, 0.0),
            samples: [
                (
                    0,
                    Self.fact(
                        .circle, 62.320189, 5.731212, 61.3645294367, 7.86776551117, 59.9548608104,
                        9.73618207896, 4.6910436556)
                ),
                (
                    12,
                    Self.fact(
                        .circle, -52.7295516175, -26.001442797, -52.3200686347, -29.7311706681,
                        -50.5520693262, -33.0406607725, 7.54993082919)
                ),
                (
                    24,
                    Self.fact(
                        .circle, 62.7042672735, 1.6996020079, 62.7132037513, 3.73454959175,
                        62.3201911787, 5.73120495696, 4.07664032051)
                ),
            ])
    }

    /// Elliptical arcs: an ordinary one, one through parameter 0, and a clockwise one.
    @Test func t_jwwEllipseArcs() throws {
        Self.checkRun(
            try Self.jwwEllipseArcs(), count: 16, lengthSum: 120.678004318,
            pointSum: SIMD3(6976.02188198, 482.663485479, 0.0),
            samples: [
                (
                    0,
                    Self.fact(
                        .circle, 23.0264006283, 14.6504919671, 19.5832078631, 15.8838918132,
                        15.9903406192, 16.5681114903, 7.32227812768)
                ),
                (
                    8,
                    Self.fact(
                        .circle, 115.78456817, 16.5935834433, 110.778261065, 16.8509645937,
                        105.776632028, 16.5147163758, 10.0317055517)
                ),
                (
                    15,
                    Self.fact(
                        .circle, 215.990340619, 16.5681114903, 213.876737006, 16.769408509,
                        211.755040309, 16.8484265469, 4.2469248878)
                ),
            ])
    }

    /// Four lines and four true arcs, in the chain's order.
    @Test func t_contourRoundedRectangle() throws {
        let faces = try Self.contourFixture("rounded_rect")
        #expect(faces.count == 1)
        guard let face = faces.first else { return }
        Self.check(
            face,
            [
                Self.fact(.line, 5.0, 0.0, 20.0, 0.0, 35.0, 0.0, 30.0),
                Self.fact(
                    .circle, 35.0, 0.0, 38.5355339059, 1.46446609407, 40.0, 5.0, 7.85398163397),
                Self.fact(.line, 40.0, 5.0, 40.0, 10.0, 40.0, 15.0, 10.0),
                Self.fact(
                    .circle, 40.0, 15.0, 38.5355339059, 18.5355339059, 35.0, 20.0, 7.85398163397),
                Self.fact(.line, 35.0, 20.0, 20.0, 20.0, 5.0, 20.0, 30.0),
                Self.fact(
                    .circle, 5.0, 20.0, 1.46446609407, 18.5355339059, 0.0, 15.0, 7.85398163397),
                Self.fact(.line, 0.0, 15.0, 0.0, 10.0, 0.0, 5.0, 10.0),
                Self.fact(.circle, 0.0, 5.0, 1.46446609407, 1.46446609407, 5.0, 0.0, 7.85398163397),
            ])
    }

    /// The outline's four lines, then each hole's two half circles.
    @Test func t_contourPlateWithHoles() throws {
        let faces = try Self.contourFixture("plate_holes")
        #expect(faces.count == 1)
        guard let face = faces.first else { return }
        Self.check(
            face,
            [
                Self.fact(.line, 0.0, 0.0, 50.0, 0.0, 100.0, 0.0, 100.0),
                Self.fact(.line, 100.0, 0.0, 100.0, 30.0, 100.0, 60.0, 60.0),
                Self.fact(.line, 100.0, 60.0, 50.0, 60.0, 0.0, 60.0, 100.0),
                Self.fact(.line, 0.0, 60.0, 0.0, 30.0, 0.0, 0.0, 60.0),
                Self.fact(.circle, 15.0, 30.0, 20.0, 25.0, 25.0, 30.0, 15.7079632679),
                Self.fact(.circle, 25.0, 30.0, 20.0, 35.0, 15.0, 30.0, 15.7079632679),
                Self.fact(.circle, 45.0, 30.0, 50.0, 25.0, 55.0, 30.0, 15.7079632679),
                Self.fact(.circle, 55.0, 30.0, 50.0, 35.0, 45.0, 30.0, 15.7079632679),
                Self.fact(.circle, 75.0, 30.0, 80.0, 25.0, 85.0, 30.0, 15.7079632679),
                Self.fact(.circle, 85.0, 30.0, 80.0, 35.0, 75.0, 30.0, 15.7079632679),
            ])
    }

    /// Arcs that arrive reversed and out of order come out counter-clockwise.
    @Test func t_contourSlotFromReversedArcs() throws {
        let faces = try Self.contourFixture("slot_shuffled")
        #expect(faces.count == 1)
        guard let face = faces.first else { return }
        Self.check(
            face,
            [
                Self.fact(.circle, 20.0, -10.0, 30.0, 0.0, 20.0, 10.0, 31.4159265359),
                Self.fact(.line, 20.0, 10.0, 10.0, 10.0, 0.0, 10.0, 20.0),
                Self.fact(.circle, 0.0, 10.0, -10.0, 0.0, 0.0, -10.0, 31.4159265359),
                Self.fact(.line, 0.0, -10.0, 10.0, -10.0, 20.0, -10.0, 20.0),
            ])
    }

    /// A spline closed by a line, fitted to arcs.
    @Test func t_contourSplineFixture() throws {
        let faces = try Self.contourFixture("spline")
        #expect(faces.count == 1)
        guard let face = faces.first else { return }
        Self.checkRun(
            face, count: 23, lengthSum: 184.720129288,
            pointSum: SIMD3(2973.72107592, 1106.68470817, 0.0),
            samples: [
                (0, Self.fact(.line, 0.0, 0.0, 40.0, 0.0, 80.0, 0.0, 80.0)),
                (
                    11,
                    Self.fact(
                        .circle, 44.5982487996, 18.2798449198, 46.7622995318, 17.6095674047,
                        48.9877446493, 17.1855608622, 4.53332758252)
                ),
                (
                    22,
                    Self.fact(
                        .circle, 3.74674479167, 8.35530598958, 1.78061370761, 4.21924849499, 0.0,
                        0.0, 9.15993203696)
                ),
            ])
    }

    /// A rectangle with a fitted ellipse as its hole.
    @Test func t_contourEllipseHole() throws {
        let faces = try Self.contourEllipses()
        #expect(faces.count == 1)
        guard let face = faces.first else { return }
        Self.checkRun(
            face, count: 24, lengthSum: 392.773262616,
            pointSum: SIMD3(2422.89896615, 2168.03314124, 0.0),
            samples: [
                (0, Self.fact(.line, 0.0, 0.0, 50.0, 0.0, 100.0, 0.0, 100.0)),
                (
                    12,
                    Self.fact(
                        .circle, 16.2720189652, 23.442825238, 17.0727084402, 23.0078902574,
                        17.9281618358, 22.6940884716, 1.82400544018)
                ),
                (
                    23,
                    Self.fact(
                        .circle, 45.0, 35.0, 44.6199249434, 35.7303601955, 44.0474059764,
                        36.3220569897, 1.65242145599)
                ),
            ])
    }

    /// A line; one arc counter-clockwise and clockwise; minor and major arcs; a segment of no length.
    @Test func t_contourSegments() throws {
        let got = Self.segmentEdges()
        #expect(got.count == 7)
        Self.check(
            got.compactMap { $0 },
            [
                Self.fact(.line, 0.0, 0.0, 1.5, 2.0, 3.0, 4.0, 5.0),
                Self.fact(.circle, 0.0, 0.0, 1.0, -1.0, 2.0, 0.0, 3.14159265359),
                Self.fact(.circle, 0.0, 0.0, 1.0, -1.0, 2.0, 0.0, 3.14159265359),
                Self.fact(.circle, 0.0, 0.0, 2.0, -0.5, 4.0, 0.0, 4.16463727316),
                Self.fact(.circle, 4.0, 0.0, 2.0, 4.0, 0.0, 0.0, 11.0714871779),
                Self.fact(.circle, 0.0, 0.0, 2.0, -6.0, 4.0, 0.0, 16.653943632),
            ])
        #expect(got.indices.contains(6) && got[6] == nil)
    }
}

// MARK: The inputs, one function each, so a table can pin what each builds

extension PlanarEdgeCharacterizationTests {

    // The shapes path, from DXF text.

    /// A line, and a line from a point to itself, which adds nothing.
    static func dxfLines() throws -> [Facts] {
        try dxfEdges([line(0, 0, 3, 4), line(5, 5, 5, 5), line(-2, 1, 6, 1)])
    }

    /// A circle, and a circle of radius 0, which adds nothing.
    static func dxfCircles() throws -> [Facts] {
        try dxfEdges([circle(10, 20, 5), circle(0, 0, 0)])
    }

    /// An arc, an arc through the angle 0 (start after end), a full turn (start equals end) and an
    /// arc of radius 0, which adds nothing.
    static func dxfArcs() throws -> [Facts] {
        try dxfEdges([
            arc(1, 2, 3, from: 30, to: 120), arc(-4, 0, 2, from: 300, to: 60),
            arc(0, 0, 4, from: 90, to: 90), arc(1, 1, 0, from: 0, to: 90),
        ])
    }

    /// A closed polyline with one bulged segment, an open one with two coincident vertices, and
    /// one with a single vertex, which is a point.
    static func dxfPolylines() throws -> [Facts] {
        try dxfEdges([
            polyline([(0, 0, 0), (4, 0, 0.5), (4, 3, 0)], closed: true),
            polyline([(10, 0, 0), (10, 0, 0), (12, 2, 0)], closed: false),
            polyline([(20, 20, 0)], closed: false),
        ])
    }

    /// A bulge of 1 is a semicircle; a bulge of -2 a clockwise arc of more than a half turn.
    static func dxfBulges() throws -> [Facts] {
        try dxfEdges([
            polyline([(0, 0, 1), (2, 0, 0)], closed: false),
            polyline([(10, 0, -2), (13, 1, 0)], closed: false),
        ])
    }

    /// The positions of the vertices a POINT and a one-vertex polyline add, which are all a
    /// compound of just those two holds.
    static func dxfVertices() throws -> [SIMD3<Double>] {
        let result = try DXFLoader.shapes(
            of: dxf([point(3, 4), polyline([(20, 20, 0)], closed: false)]), layersKnown: true)
        guard let shape = result.shapes.first else { return [] }
        return shape.subShapes(ofType: .vertex).compactMap { vertex in
            vertex.bounds.map { ($0.min + $0.max) / 2 }
        }
    }

    /// A full ellipse, tilted; its major axis points down-left.
    static func dxfEllipseFull() throws -> [Facts] {
        try dxfEdges([ellipse(center: SIMD2(5, -12), major: SIMD2(-60, -35), ratio: 0.3)])
    }

    /// An arc of an ellipse, and one that passes through its parameter 0 (start after end).
    static func dxfEllipseArcs() throws -> [Facts] {
        try dxfEdges([
            ellipse(center: SIMD2(0, 0), major: SIMD2(30, 10), ratio: 0.5, start: 0.5, end: 2.0),
            ellipse(center: SIMD2(100, 0), major: SIMD2(30, 10), ratio: 0.5, start: 5.0, end: 1.0),
        ])
    }

    /// A circle drawn as an ellipse.
    static func dxfEllipseCircle() throws -> [Facts] {
        try dxfEdges([ellipse(center: SIMD2(20, 30), major: SIMD2(50, 0), ratio: 1)])
    }

    // The shapes path, from JWW.

    static func jwwLineAndCircle() throws -> [Facts] {
        try jwwEdges(
            jww(objects: 3) { b in
                jwwLine(&b, 0, 0, 3, 4)
                jwwEnko(&b, center: (10, 20), radius: 5, full: true)
                jwwLine(&b, 7, 7, 7, 7)
            })
    }

    /// Three circular arcs: an ordinary one, one that passes through angle 0, and a clockwise one
    /// (a negative sweep).
    static func jwwArcs() throws -> [Facts] {
        try jwwEdges(
            jww(objects: 3) { b in
                jwwEnko(&b, center: (1, 2), radius: 3, start: 0.5, sweep: 1.5, full: false)
                jwwEnko(&b, center: (-4, 0), radius: 2, start: 5.5, sweep: 2.0, full: false)
                jwwEnko(&b, center: (9, 9), radius: 2, start: 1.0, sweep: -2.0, full: false)
            })
    }

    static func jwwEllipseFull() throws -> [Facts] {
        try jwwEdges(
            jww(objects: 1) { b in
                jwwEnko(&b, center: (5, -12), radius: 60, tilt: 0.3, ratio: 0.4, full: true)
            })
    }

    /// Elliptical arcs: an ordinary one, one that passes through parameter 0, and one with a
    /// negative sweep.
    static func jwwEllipseArcs() throws -> [Facts] {
        try jwwEdges(
            jww(objects: 3) { b in
                jwwEnko(
                    &b, center: (0, 0), radius: 30, start: 0.5, sweep: 1.5, tilt: 0.3, ratio: 0.5,
                    full: false)
                jwwEnko(
                    &b, center: (100, 0), radius: 30, start: 5.5, sweep: 2.0, tilt: 0.3, ratio: 0.5,
                    full: false)
                jwwEnko(
                    &b, center: (200, 0), radius: 30, start: 1.0, sweep: -2.0, tilt: 0.3,
                    ratio: 0.5, full: false)
            })
    }

    // The contour path.

    static func contourFixture(_ name: String) throws -> [[Facts]] {
        contourEdges(try DXFLoader.loadContours(from: DXFContourTests.fixture(name)))
    }

    /// A rectangle with a full ellipse as a hole and an elliptical arc closed by a line.
    static func contourEllipses() throws -> [[Facts]] {
        let drawing = try dxf([
            line(0, 0, 100, 0), line(100, 0, 100, 60), line(100, 60, 0, 60), line(0, 60, 0, 0),
            ellipse(center: SIMD2(30, 30), major: SIMD2(15, 5), ratio: 0.4),
        ])
        return contourEdges(DXFLoader.contourFaces(of: drawing))
    }

    /// Segments handed to `DXFLoader.edge(for:)`: a line, counter-clockwise and clockwise arcs
    /// (the same arc either way), a minor and a major arc, and a bulged segment of no length.
    static func segmentEdges() -> [Facts?] {
        func s(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ bulge: Double)
            -> DXF.Contour.Segment
        {
            DXF.Contour.Segment(
                start: DXF.Point2(x1, y1), end: DXF.Point2(x2, y2), bulge: bulge)
        }
        return [
            s(0, 0, 3, 4, 0), s(0, 0, 2, 0, 1), s(2, 0, 0, 0, -1), s(0, 0, 4, 0, 0.25),
            s(0, 0, 4, 0, -2), s(0, 0, 4, 0, 3), s(1, 1, 1, 1, 0.5),
        ].map(segmentEdge)
    }
}
