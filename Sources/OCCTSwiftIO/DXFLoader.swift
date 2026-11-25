// DXFLoader.swift
// OCCTSwiftIO
//
// Loads DXF (AutoCAD Drawing Interchange Format), a 2D vector drawing, into OCCT geometry. Like JWW,
// DXF is not a B-Rep solid or a mesh; it's lines, arcs/circles, ellipses, points and text in a plane.
// We map the drawable curve entities to OCCT edges (in the Z=0 plane) and return them as one compound
// `Shape`. Splines and ellipses are fitted to lines and circular arcs within a tolerance. Text is not
// converted to geometry (it would need font outlines), and nor are dimensions, hatches, leaders,
// tolerance frames, solid fills, wipeouts or 3D faces: each is counted in a `.noEdges` warning.
// Geometry with no size, and geometry OCCT or the curve fit makes no edge of, is counted in a
// `.degenerate` or `.notBuilt` warning. Block references are expanded, and what the read left out
// is returned as `DrawingWarning`s.
// Reading is delegated to SwiftDXF, which is validated bit-exact against the ezdxf reference reader.

import Foundation
import OCCTSwift
// Re-export so `import OCCTSwiftIO` brings the DXF entity model (DXF.Drawing / DXF.Entity, with TEXT
// strings, per-entity layers, $INSUNITS and extents) into scope: that entity model is the primary
// deliverable; the OCCT `Shape` compound below is the optional convenience.
@_exported import SwiftDXF

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

    /// How `ShapeLoader` reads a DXF, a DWG or a JWW: with block references expanded, as
    /// `DrawingLoader` does, so the geometry in a block is in the compound and the two loaders
    /// agree on what a drawing holds (#70).
    ///
    /// The visible attributes of a reference, and the constant ones of its block, come through as
    /// `TEXT` as well, so that the `.noEdges` warning counts them: SwiftDXF 0.6 keeps an attribute
    /// off the entities otherwise, and a drawing's drawn text would be counted short.
    static let shapeReadOptions = DXF.ReadOptions(expandBlocks: true, expandAttributes: true)

    static func load(from url: URL) throws -> ShapeLoadResult {
        shapes(of: try DXF.read(contentsOf: url, options: shapeReadOptions), layersKnown: true)
    }

    /// One compound of curve edges for a drawing, whichever format it was read from, and the
    /// warnings of the read.
    ///
    /// Shared by the DXF, DWG and JWW loaders: all three come back as the same `DXF.Drawing`.
    /// `drawing` is expected to have been read with ``shapeReadOptions``; the warnings are
    /// `DrawingLoader`'s for such a read, and then a `.noEdges` warning for each type and layer of
    /// entity that was read and has no edges here, and a `.degenerate` or `.notBuilt` one for
    /// each drawable entity, segment or piece that made none. `layersKnown` is `false` for a DWG,
    /// which counts what it skipped without a layer; the entities it read have theirs.
    static func shapes(of drawing: DXF.Drawing, layersKnown: Bool) -> ShapeLoadResult {
        var shapes: [Shape] = []
        var noEdges = NoEdgeTally()
        var dropped = DroppedTally()

        let deg = Double.pi / 180
        let tolerance = fitTolerance(of: drawing)

        /// Keeps `edge`, or counts that it could not be made.
        func keep(
            _ edge: Shape?, type: String, layer: String, unit: DroppedTally.Unit = .entities
        ) {
            if let edge {
                shapes.append(edge)
            } else {
                dropped.add(.notBuilt, type: type, layer: layer, unit: unit)
            }
        }

        /// Keeps the lines and arcs an ellipse or a spline is fitted to.
        func keepFit(of entity: DXF.Entity, type: String, layer: String) {
            // Lines and circular arcs within `tolerance`, the fit SwiftDXF's contour layer makes,
            // so a spline that is really a line or an arc is one edge of that kind and an
            // ellipse has a stated tolerance in place of a fixed number of chords (#75). A JWW's
            // elliptical arcs come here too, as SwiftJWW writes them as ELLIPSE.
            let pieces = entity.fitted(tolerance: tolerance)?.pieces ?? []
            if pieces.isEmpty {
                dropped.add(.noFit, type: type, layer: layer)
            }
            for piece in pieces {
                keep(edge(for: piece.segment), type: type, layer: layer, unit: .pieces)
            }
        }

        for entity in drawing.entities {
            switch entity {
            case .line(let a, let b, let layer, _):
                if a == b {
                    dropped.add(.noLength, type: "LINE", layer: layer)
                } else {
                    keep(PlanarEdge.line(from: a, to: b), type: "LINE", layer: layer)
                }

            case .circle(let c, let r, let layer, _):
                if r > 0 {
                    keep(
                        PlanarEdge.arc(center: c, radius: r, from: 0, to: 2 * .pi),
                        type: "CIRCLE", layer: layer)
                } else {
                    dropped.add(.noRadius, type: "CIRCLE", layer: layer)
                }

            case .arc(let c, let r, let startDeg, let endDeg, let layer, _):
                guard r > 0 else {
                    dropped.add(.noRadius, type: "ARC", layer: layer)
                    continue
                }
                // DXF arcs sweep CCW from start to end (degrees); unwrap so the end exceeds the start.
                let p1 = startDeg * deg
                var p2 = endDeg * deg
                if p2 <= p1 { p2 += 2 * .pi }
                keep(
                    PlanarEdge.arc(center: c, radius: r, from: p1, to: p2),
                    type: "ARC", layer: layer)

            case .point(let p, let layer, _):
                keep(PlanarEdge.vertex(at: p), type: "POINT", layer: layer)

            case .polyline(let verts, let closed, let layer, _):
                guard verts.count >= 2 else {
                    if let v = verts.first {
                        keep(PlanarEdge.vertex(at: v.point), type: "POLYLINE", layer: layer)
                    } else {
                        dropped.add(.noVertices, type: "POLYLINE", layer: layer)
                    }
                    continue
                }
                let n = verts.count
                let segs = closed ? n : n - 1
                for i in 0..<segs {
                    let a = verts[i]
                    let b = verts[(i + 1) % n]
                    if a.point == b.point {
                        dropped.add(.noLength, type: "POLYLINE", layer: layer, unit: .segments)
                        continue
                    }
                    let edge =
                        abs(a.bulge) < 1e-12
                        ? PlanarEdge.line(from: a.point, to: b.point)
                        : bulgeArc(a.point, b.point, bulge: a.bulge)
                    keep(edge, type: "POLYLINE", layer: layer, unit: .segments)
                }

            case .ellipse(_, _, _, _, _, let layer, _):
                keepFit(of: entity, type: "ELLIPSE", layer: layer)

            case .spline(let spline):
                keepFit(of: entity, type: "SPLINE", layer: spline.layer)

            case .text, .dimension, .hatch, .leader, .tolerance, .solid, .wipeout, .face3D:
                // Annotation (text, dimension, leader, tolerance frame), fill (hatch, solid), mask
                // (wipeout) and 3D face: no drawable curve of their own here. Counted, not dropped
                // without a word.
                noEdges.add(entity)
            }
        }

        let compound = Shape.compound(shapes)
        if compound == nil { dropped.addUnjoined(shapes.count) }
        let warnings =
            DrawingLoader.warnings(for: drawing, expandedBlocks: true, layersKnown: layersKnown)
            + noEdges.warnings + dropped.warnings
        guard let compound else {
            return ShapeLoadResult(shapesWithColors: [], warnings: warnings)
        }
        return ShapeLoadResult(
            shapesWithColors: [(shape: compound, color: nil)], warnings: warnings)
    }

    /// The circular-arc edge for a bulged polyline segment, through the contour layer's segment
    /// geometry (`bulge = tan(sweep / 4)`, positive counter-clockwise).
    private static func bulgeArc(_ a: DXF.Point, _ b: DXF.Point, bulge: Double) -> Shape? {
        let segment = DXF.Contour.Segment(
            start: DXF.Point2(a.x, a.y), end: DXF.Point2(b.x, b.y), bulge: bulge)
        return edge(for: segment)
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
