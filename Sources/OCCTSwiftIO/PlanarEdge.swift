// PlanarEdge.swift
// OCCTSwiftIO
//
// Where a drawing's x and y become an OCCT vertex, line or circular arc in the Z = 0 plane. The
// shapes path (`DXFLoader.shapes(of:layersKnown:)`, for DXF, DWG and JWW) and the contour path
// (`DXFLoader.edge(for:)`) both build their edges here; each keeps its own rules for which
// segments to keep and how to bring an arc's angles into range.

import OCCTSwift
import SwiftDXF

/// A point of a drawing with an x and a y: SwiftDXF's `Point`, whose z is dropped, and `Point2`.
protocol PlanarPoint {
    var x: Double { get }
    var y: Double { get }
}

extension DXF.Point: PlanarPoint {}
extension DXF.Point2: PlanarPoint {}

enum PlanarEdge {

    /// The point of the drawing in the Z = 0 plane.
    private static func lifted(_ p: some PlanarPoint) -> SIMD3<Double> { SIMD3(p.x, p.y, 0) }

    /// A vertex at `p`.
    static func vertex(at p: some PlanarPoint) -> Shape? {
        Shape.vertex(at: lifted(p))
    }

    /// A straight edge from `a` to `b`, `nil` where OCCT cannot make one, as between equal points.
    static func line(from a: some PlanarPoint, to b: some PlanarPoint) -> Shape? {
        Shape.edgeFromPoints(lifted(a), lifted(b))
    }

    /// A circular arc about `center`, counter-clockwise seen from +Z from `startAngle` to
    /// `endAngle` (radians); a span of 2 pi is the full circle.
    static func arc(
        center: some PlanarPoint, radius: Double, from startAngle: Double, to endAngle: Double
    ) -> Shape? {
        Shape.edgeFromCircle(
            center: lifted(center), axis: SIMD3(0, 0, 1), radius: radius, p1: startAngle,
            p2: endAngle)
    }
}
