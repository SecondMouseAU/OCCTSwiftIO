// DXFLoader.swift
// OCCTSwiftIO
//
// Loads DXF (AutoCAD Drawing Interchange Format) — a 2D vector drawing — into OCCT geometry. Like JWW,
// DXF is not a B-Rep solid or a mesh; it's lines, arcs/circles, ellipses, points and text in a plane.
// We map the drawable curve entities to OCCT edges (in the Z=0 plane) and return them as one compound
// `Shape`. Text is not converted to geometry (it would need font outlines). Reading is delegated to
// SwiftDXF, which is validated bit-exact against the ezdxf reference reader.

import Foundation
import simd
import OCCTSwift
// Re-export so `import OCCTSwiftIO` brings the DXF entity model (DXF.Drawing / DXF.Entity, with TEXT
// strings, per-entity layers, $INSUNITS and extents) into scope — that entity model is the primary
// deliverable; the OCCT `Shape` compound below is the optional convenience.
@_exported import SwiftDXF

public enum DXFLoader {

    /// Read a DXF file into the neutral SwiftDXF entity model (geometry + TEXT + layers + header).
    /// This is the entity-level surface; use ``load(from:)`` (or `ShapeLoader`) for the OCCT compound.
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
            case let .line(a, b, _, _):
                if a != b, let s = Shape.edgeFromPoints(p3(a.x, a.y), p3(b.x, b.y)) { shapes.append(s) }

            case let .circle(c, r, _, _):
                guard r > 0 else { continue }
                if let s = Shape.edgeFromCircle(center: p3(c.x, c.y), axis: axis, radius: r, p1: 0, p2: 2 * .pi) {
                    shapes.append(s)
                }

            case let .arc(c, r, startDeg, endDeg, _, _):
                guard r > 0 else { continue }
                // DXF arcs sweep CCW from start to end (degrees); unwrap so the end exceeds the start.
                let p1 = startDeg * deg
                var p2 = endDeg * deg
                if p2 <= p1 { p2 += 2 * .pi }
                if let s = Shape.edgeFromCircle(center: p3(c.x, c.y), axis: axis, radius: r, p1: p1, p2: p2) {
                    shapes.append(s)
                }

            case let .ellipse(c, major, ratio, startParam, endParam, _, _):
                // OCCT's edgeFromEllipse can't express a rotated major axis, so polyline it (carrying the
                // tilt), matching JWWLoader's treatment of elliptical arcs.
                let majorR = (major.x * major.x + major.y * major.y).squareRoot()
                guard majorR > 0 else { continue }
                emitEllipsePolyline(cx: c.x, cy: c.y, majorR: majorR, ratio: ratio,
                                    tilt: atan2(major.y, major.x),
                                    start: startParam, end: endParam, into: &shapes)

            case let .point(p, _, _):
                if let v = Shape.vertex(at: p3(p.x, p.y)) { shapes.append(v) }

            case let .polyline(verts, closed, _, _):
                guard verts.count >= 2 else {
                    if let v = verts.first, let vx = Shape.vertex(at: p3(v.point.x, v.point.y)) { shapes.append(vx) }
                    continue
                }
                let n = verts.count
                let segs = closed ? n : n - 1
                for i in 0..<segs {
                    let a = verts[i], b = verts[(i + 1) % n]
                    if a.point == b.point { continue }
                    if abs(a.bulge) < 1e-12 {
                        if let s = Shape.edgeFromPoints(p3(a.point.x, a.point.y), p3(b.point.x, b.point.y)) {
                            shapes.append(s)
                        }
                    } else {
                        emitBulgeArc(a.point, b.point, bulge: a.bulge, axis: axis, into: &shapes)
                    }
                }

            case .text:
                break   // text → no geometry
            }
        }

        guard let compound = Shape.compound(shapes) else { return ShapeLoadResult(shapesWithColors: []) }
        return ShapeLoadResult(shapesWithColors: [(shape: compound, color: nil)])
    }

    /// Emit one circular-arc edge for a bulged polyline segment. `bulge = tan(θ/4)` where θ is the
    /// included angle, swept CCW from `a` to `b` (the AutoCAD/ezdxf convention). Center derived as
    /// `h = (1/b − b)/2`; the arc is added over its angular interval.
    private static func emitBulgeArc(_ a: DXF.Point, _ b: DXF.Point, bulge: Double,
                                     axis: SIMD3<Double>, into shapes: inout [Shape]) {
        let h = (1 / bulge - bulge) / 2
        let cx = (a.x + b.x) / 2 + h * (a.y - b.y) / 2
        let cy = (a.y + b.y) / 2 + h * (b.x - a.x) / 2
        let r = (pow(a.x - cx, 2) + pow(a.y - cy, 2)).squareRoot()
        guard r > 0 else { return }
        let phi1 = atan2(a.y - cy, a.x - cx)
        let theta = 4 * atan(bulge)
        let lo = min(phi1, phi1 + theta), hi = max(phi1, phi1 + theta)
        if let s = Shape.edgeFromCircle(center: SIMD3(cx, cy, 0), axis: axis, radius: r, p1: lo, p2: hi) {
            shapes.append(s)
        }
    }

    /// Sample an elliptical arc into edges. `start`/`end` are the DXF ellipse parameters (radians);
    /// `tilt` rotates the major axis. Mirrors JWWLoader.emitEllipsePolyline.
    private static func emitEllipsePolyline(cx: Double, cy: Double, majorR: Double, ratio: Double,
                                            tilt: Double, start: Double, end: Double, into shapes: inout [Shape]) {
        let n = 48
        var a1 = end
        if a1 <= start { a1 += 2 * .pi }
        let ct = cos(tilt), st = sin(tilt)
        func pt(_ a: Double) -> SIMD3<Double> {
            let ex = majorR * cos(a), ey = majorR * ratio * sin(a)
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
