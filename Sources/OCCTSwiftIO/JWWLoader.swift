// JWWLoader.swift
// OCCTSwiftIO
//
// Loads JWW (Jw_cad) — a 2D vector drawing — into OCCT geometry. JWW is not a B-Rep solid or a mesh;
// it's lines, arcs/circles, points and text in a plane. We map the drawable curve entities to OCCT
// edges (in the Z=0 plane) and return them as one compound `Shape`. Text is not converted to geometry
// (it would need font outlines); block inserts are not yet expanded. Reading is delegated to SwiftJWW.

import Foundation
import simd
import OCCTSwift
import SwiftJWW

enum JWWLoader {

    static func load(from url: URL) throws -> ShapeLoadResult {
        let drawing = try JWW.read(contentsOf: url)
        var shapes: [Shape] = []

        func p3(_ x: Double, _ y: Double) -> SIMD3<Double> { SIMD3(x, y, 0) }

        let axis = SIMD3<Double>(0, 0, 1)

        func emit(_ entity: JWW.Entity) {
            switch entity {
            case let .line(a, b, _, _):
                if a != b, let s = Shape.edgeFromPoints(p3(a.x, a.y), p3(b.x, b.y)) { shapes.append(s) }
            case let .arc(c, r, start, sweep, tilt, ratio, full, _, _):
                let cx = c.x, cy = c.y
                guard r > 0 else { return }
                if abs(ratio - 1) < 1e-9 {                                  // circle / circular arc
                    let (p1, p2): (Double, Double)
                    if full || abs(abs(sweep) - 2 * .pi) < 1e-6 { (p1, p2) = (0, 2 * .pi) }
                    else {
                        // start/sweep are measured from the tilt axis (matches the DXF mapping); span CCW.
                        let a = tilt + start, b = tilt + start + sweep
                        (p1, p2) = (min(a, b), max(a, b))
                    }
                    if let s = Shape.edgeFromCircle(center: SIMD3(cx, cy, 0), axis: axis, radius: r, p1: p1, p2: p2) { shapes.append(s) }
                } else {                                                     // ellipse → polyline (carries tilt)
                    emitEllipsePolyline(cx: cx, cy: cy, r: r, ratio: ratio, tilt: tilt,
                                        start: start, sweep: sweep, full: full, into: &shapes)
                }
            case let .point(pt, _, _):
                if let v = Shape.vertex(at: p3(pt.x, pt.y)) { shapes.append(v) }
            case let .dimension(parts, _):
                for part in parts { emit(part) }              // dimension line + witness lines + text(skipped)
            case .text, .insert:
                break                                          // text → no geometry; inserts not yet expanded
            }
        }
        for entity in drawing.entities { emit(entity) }

        guard let compound = Shape.compound(shapes) else { return ShapeLoadResult(shapesWithColors: []) }
        return ShapeLoadResult(shapesWithColors: [(shape: compound, color: nil)])
    }

    private static func emitEllipsePolyline(cx: Double, cy: Double, r: Double, ratio: Double, tilt: Double,
                                            start: Double, sweep: Double, full: Bool, into shapes: inout [Shape]) {
        let n = 48
        let a0 = full ? 0 : start, a1 = full ? 2 * .pi : start + sweep
        let ct = cos(tilt), st = sin(tilt)
        func pt(_ a: Double) -> SIMD3<Double> {
            let ex = r * cos(a), ey = r * ratio * sin(a)
            return SIMD3(cx + ex * ct - ey * st, cy + ex * st + ey * ct, 0)
        }
        var prev = pt(a0)
        for i in 1...n {
            let cur = pt(a0 + (a1 - a0) * Double(i) / Double(n))
            if let s = Shape.edgeFromPoints(prev, cur) { shapes.append(s) }
            prev = cur
        }
    }
}
