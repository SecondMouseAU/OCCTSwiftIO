// DXFLoader.swift
// OCCTSwiftIO
//
// Loads DXF (AutoCAD Drawing Interchange Format), a 2D vector drawing, into OCCT geometry. Like JWW,
// DXF is not a B-Rep solid or a mesh; it's lines, arcs/circles, ellipses, points and text in a plane.
// We map the drawable curve entities to OCCT edges (in the Z=0 plane) and return them as one compound
// `Shape`. Splines and ellipses are fitted to lines and circular arcs within a tolerance. Text is not
// converted to geometry (it would need font outlines). Block references are expanded, and what the
// read left out is returned as `DrawingWarning`s. Reading is delegated to SwiftDXF, which is
// validated bit-exact against the ezdxf reference reader.

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
    public static func readEntities(
        from url: URL, options: DXF.ReadOptions = .init()
    ) throws -> DXF.Drawing {
        try DXF.read(contentsOf: url, options: options)
    }

    /// How `ShapeLoader` reads a DXF or a DWG: with block references expanded, as `DrawingLoader`
    /// does, so the geometry in a block is in the compound and the two loaders agree on what a
    /// drawing holds (#70).
    static let shapeReadOptions = DXF.ReadOptions(expandBlocks: true)

    static func load(from url: URL) throws -> ShapeLoadResult {
        shapes(of: try DXF.read(contentsOf: url, options: shapeReadOptions), layersKnown: true)
    }

    /// One compound of curve edges for a drawing, whichever format it was read from, and the
    /// warnings of the read.
    ///
    /// Shared by the DXF and DWG loaders: both come back as the same `DXF.Drawing`. `drawing` is
    /// expected to have been read with ``shapeReadOptions``; the warnings are `DrawingLoader`'s for
    /// such a read. `layersKnown` is `false` for a DWG, which counts what it skipped without a layer.
    static func shapes(of drawing: DXF.Drawing, layersKnown: Bool) -> ShapeLoadResult {
        var shapes: [Shape] = []

        func p3(_ x: Double, _ y: Double) -> SIMD3<Double> { SIMD3(x, y, 0) }
        let axis = SIMD3<Double>(0, 0, 1)
        let deg = Double.pi / 180
        let tolerance = fitTolerance(of: drawing)

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

            case .ellipse, .spline:
                // Lines and circular arcs within `tolerance`, the fit SwiftDXF's contour layer makes,
                // so a spline that is really a line or an arc is one edge of that kind and an
                // ellipse has a stated tolerance in place of a fixed number of chords (#75).
                for piece in entity.fitted(tolerance: tolerance)?.pieces ?? [] {
                    if let s = edge(for: piece.segment) { shapes.append(s) }
                }

            case .text:
                break  // text → no geometry

            case .dimension:
                // dimension → annotation (extent/extension lines, text, arrows), not drawable curve geometry
                break

            case .hatch, .leader:
                break  // fill and annotation, not edges
            }
        }

        let warnings = DrawingLoader.warnings(
            for: drawing, expandedBlocks: true, layersKnown: layersKnown)
        guard let compound = Shape.compound(shapes) else {
            return ShapeLoadResult(shapesWithColors: [], warnings: warnings)
        }
        return ShapeLoadResult(
            shapesWithColors: [(shape: compound, color: nil)], warnings: warnings)
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

    /// The fit tolerance: one ten-thousandth of the drawing's diagonal.
    ///
    /// Relative to the drawing so it holds in any unit; the shapes path works in the drawing's own.
    private static func fitTolerance(of drawing: DXF.Drawing) -> Double {
        guard let b = drawing.bounds else { return 1e-6 }
        let diagonal =
            ((b.max.x - b.min.x) * (b.max.x - b.min.x)
            + (b.max.y - b.min.y) * (b.max.y - b.min.y)).squareRoot()
        return max(diagonal * 1e-4, 1e-9)
    }
}
