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
import SwiftDXF

enum DXFLoader {

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

            case let .polyline(points, closed, _, _):
                var pts = points
                if closed, let first = points.first, points.count > 2 { pts.append(first) }
                for i in 1..<max(pts.count, 1) {
                    let a = pts[i - 1], b = pts[i]
                    if a != b, let s = Shape.edgeFromPoints(p3(a.x, a.y), p3(b.x, b.y)) { shapes.append(s) }
                }

            case .text:
                break   // text → no geometry
            }
        }

        guard let compound = Shape.compound(shapes) else { return ShapeLoadResult(shapesWithColors: []) }
        return ShapeLoadResult(shapesWithColors: [(shape: compound, color: nil)])
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
