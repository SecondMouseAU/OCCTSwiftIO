// DXFLoader.swift
// OCCTSwiftIO
//
// Loads DXF (AutoCAD Drawing Interchange Format), a 2D vector drawing, into OCCT geometry. Like JWW,
// DXF is not a B-Rep solid or a mesh; it's lines, arcs/circles, ellipses, points and text in a plane.
// We map the drawable curve entities to OCCT edges (in the Z=0 plane) and return them as one compound
// `Shape`. Text is not converted to geometry (it would need font outlines). Reading is delegated to
// SwiftDXF, which is validated bit-exact against the ezdxf reference reader.

import Foundation
import OCCTSwift
// Re-export so `import OCCTSwiftIO` brings the DXF entity model (DXF.Drawing / DXF.Entity, with TEXT
// strings, per-entity layers, $INSUNITS and extents) into scope: that entity model is the primary
// deliverable; the OCCT `Shape` compound below is the optional convenience.
@_exported import SwiftDXF
import simd

public enum DXFLoader {

    /// Read a DXF file into the neutral SwiftDXF entity model (geometry + TEXT + layers + header).
    ///
    /// This is the entity-level surface; use ``load(from:)`` (or `ShapeLoader`) for the OCCT
    /// compound.
    public static func readEntities(from url: URL) throws -> DXF.Drawing {
        try DXF.read(contentsOf: url)
    }

    static func load(from url: URL) throws -> ShapeLoadResult {
        let drawing = try DXF.read(contentsOf: url)
        var shapes: [Shape] = []

        func p3(_ x: Double, _ y: Double) -> SIMD3<Double> { SIMD3(x, y, 0) }
        let axis = SIMD3<Double>(0, 0, 1)
        let deg = Double.pi / 180

        for entity in drawing.entities {
            switch entity {
            case .line(let a, let b, _, _):
                if a != b, let s = Shape.edgeFromPoints(p3(a.x, a.y), p3(b.x, b.y)) {
                    shapes.append(s)
                }

            case .circle(let c, let r, _, _):
                guard r > 0 else { continue }
                if let s = Shape.edgeFromCircle(
                    center: p3(c.x, c.y), axis: axis, radius: r, p1: 0, p2: 2 * .pi)
                {
                    shapes.append(s)
                }

            case .arc(let c, let r, let startDeg, let endDeg, _, _):
                guard r > 0 else { continue }
                // DXF arcs sweep CCW from start to end (degrees); unwrap so the end exceeds the start.
                let p1 = startDeg * deg
                var p2 = endDeg * deg
                if p2 <= p1 { p2 += 2 * .pi }
                if let s = Shape.edgeFromCircle(
                    center: p3(c.x, c.y), axis: axis, radius: r, p1: p1, p2: p2)
                {
                    shapes.append(s)
                }

            case .ellipse(let c, let major, let ratio, let startParam, let endParam, _, _):
                // OCCT's edgeFromEllipse can't express a rotated major axis, so polyline it (carrying the
                // tilt), matching JWWLoader's treatment of elliptical arcs.
                let majorR = (major.x * major.x + major.y * major.y).squareRoot()
                guard majorR > 0 else { continue }
                emitEllipsePolyline(
                    cx: c.x, cy: c.y, majorR: majorR, ratio: ratio,
                    tilt: atan2(major.y, major.x),
                    start: startParam, end: endParam, into: &shapes)

            case .point(let p, _, _):
                if let v = Shape.vertex(at: p3(p.x, p.y)) { shapes.append(v) }

            case .polyline(let verts, let closed, _, _):
                guard verts.count >= 2 else {
                    if let v = verts.first, let vx = Shape.vertex(at: p3(v.point.x, v.point.y)) {
                        shapes.append(vx)
                    }
                    continue
                }
                let n = verts.count
                let segs = closed ? n : n - 1
                for i in 0..<segs {
                    let a = verts[i]
                    let b = verts[(i + 1) % n]
                    if a.point == b.point { continue }
                    if abs(a.bulge) < 1e-12 {
                        if let s = Shape.edgeFromPoints(
                            p3(a.point.x, a.point.y), p3(b.point.x, b.point.y))
                        {
                            shapes.append(s)
                        }
                    } else {
                        emitBulgeArc(a.point, b.point, bulge: a.bulge, into: &shapes)
                    }
                }

            case .spline(let spline):
                // Flattened to a chain of straight edges. The tolerance is relative to the drawing
                // so it holds in any unit. Use `loadContours` for lines and arcs fitted to 0.01 mm.
                emitSplinePolyline(spline, tolerance: splineTolerance(drawing), into: &shapes)

            case .text:
                break  // text → no geometry

            case .dimension:
                // dimension → annotation (extent/extension lines, text, arrows), not drawable curve geometry
                break
            }
        }

        guard let compound = Shape.compound(shapes) else {
            return ShapeLoadResult(shapesWithColors: [])
        }
        return ShapeLoadResult(shapesWithColors: [(shape: compound, color: nil)])
    }

    /// Emit one circular-arc edge for a bulged polyline segment, through the contour layer's
    /// segment geometry (`bulge = tan(sweep / 4)`, positive counter-clockwise).
    private static func emitBulgeArc(
        _ a: DXF.Point, _ b: DXF.Point, bulge: Double, into shapes: inout [Shape]
    ) {
        let segment = DXF.Contour.Segment(
            start: DXF.Point2(a.x, a.y), end: DXF.Point2(b.x, b.y), bulge: bulge)
        if let s = edge(for: segment) { shapes.append(s) }
    }

    /// Flatten a spline into straight edges.
    private static func emitSplinePolyline(
        _ spline: DXF.Spline, tolerance: Double, into shapes: inout [Shape]
    ) {
        let points = spline.flattened(tolerance: tolerance)
        for (p, q) in zip(points, points.dropFirst()) {
            if let s = Shape.edgeFromPoints(SIMD3(p.x, p.y, 0), SIMD3(q.x, q.y, 0)) {
                shapes.append(s)
            }
        }
    }

    /// One ten-thousandth of the drawing's diagonal, so flattening is unit-independent.
    private static func splineTolerance(_ drawing: DXF.Drawing) -> Double {
        guard let b = drawing.bounds else { return 1e-6 }
        let diagonal =
            ((b.max.x - b.min.x) * (b.max.x - b.min.x)
            + (b.max.y - b.min.y) * (b.max.y - b.min.y)).squareRoot()
        return max(diagonal * 1e-4, 1e-9)
    }

    /// Sample an elliptical arc into edges.
    ///
    /// `start`/`end` are the DXF ellipse parameters (radians); `tilt` rotates the major axis.
    /// Mirrors JWWLoader.emitEllipsePolyline.
    private static func emitEllipsePolyline(
        cx: Double, cy: Double, majorR: Double, ratio: Double,
        tilt: Double, start: Double, end: Double, into shapes: inout [Shape]
    ) {
        let n = 48
        var a1 = end
        if a1 <= start { a1 += 2 * .pi }
        let ct = cos(tilt)
        let st = sin(tilt)
        func pt(_ a: Double) -> SIMD3<Double> {
            let ex = majorR * cos(a)
            let ey = majorR * ratio * sin(a)
            return SIMD3(cx + ex * ct - ey * st, cy + ex * st + ey * ct, 0)
        }
        var prev = pt(start)
        for i in 1...n {
            let cur = pt(start + (a1 - start) * Double(i) / Double(n))
            if let s = Shape.edgeFromPoints(prev, cur) { shapes.append(s) }
            prev = cur
        }
    }
}
