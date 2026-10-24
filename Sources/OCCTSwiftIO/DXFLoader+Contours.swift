// DXFLoader+Contours.swift
// OCCTSwiftIO
//
// Planar faces with holes from a DXF drawing. Chaining, nesting, unit conversion and the fitting of
// ellipses and splines are SwiftDXF's (`Drawing.contours`, OCCT-free); this file only turns its
// segments into OCCT edges, wires and faces.

import Foundation
import OCCTSwift
import SwiftDXF

extension DXFLoader {

    /// Read a DXF file and build a planar face per closed region, holes subtracted.
    public static func loadContours(
        from url: URL, options: DXF.Contour.Options = .init()
    ) throws -> DXFContourResult {
        contourFaces(of: try DXF.read(contentsOf: url), options: options)
    }

    /// Build a planar face per closed region of an already-read drawing.
    public static func contourFaces(
        of drawing: DXF.Drawing, options: DXF.Contour.Options = .init()
    ) -> DXFContourResult {
        let contours = drawing.contours(options)
        var faces: [DXFContourFace] = []
        var unbuilt: [DXF.Contour.Shape] = []
        // Largest outer area first, ties in SwiftDXF's order, whatever order it returns.
        let ordered = contours.shapes.enumerated().sorted {
            ($0.element.outer.area, $1.offset) > ($1.element.outer.area, $0.offset)
        }.map(\.element)
        for shape in ordered {
            if let built = face(for: shape) {
                faces.append(built)
            } else {
                unbuilt.append(shape)
            }
        }
        return DXFContourResult(
            faces: faces, unbuilt: unbuilt, openChains: contours.openChains,
            warnings: contours.warnings, unit: contours.unit, unitScale: contours.unitScale,
            maxFitDeviation: contours.maxFitDeviation)
    }

    /// The OCCT edge for one contour segment: a line, or a true circular arc.
    ///
    /// Arcs are built counter-clockwise between their two end angles whatever the segment's own
    /// direction; the wire assembly takes care of orientation.
    static func edge(for segment: DXF.Contour.Segment) -> Shape? {
        let start = SIMD3(segment.start.x, segment.start.y, 0)
        let end = SIMD3(segment.end.x, segment.end.y, 0)
        guard segment.isArc, let center = segment.center, let radius = segment.radius,
            let startAngle = segment.startAngle
        else {
            return Shape.edgeFromPoints(start, end)
        }
        let endAngle = startAngle + segment.sweep
        return Shape.edgeFromCircle(
            center: SIMD3(center.x, center.y, 0), axis: SIMD3(0, 0, 1), radius: radius,
            p1: min(startAngle, endAngle), p2: max(startAngle, endAngle))
    }

    private static func wire(for loop: DXF.Contour.Loop) -> Wire? {
        var edges: [Edge] = []
        for segment in loop.segments {
            guard let shape = edge(for: segment), let edge = Edge(shape) else { return nil }
            edges.append(edge)
        }
        return Wire.wireFromEdges(edges)
    }

    private static func face(for shape: DXF.Contour.Shape) -> DXFContourFace? {
        guard let outer = wire(for: shape.outer) else { return nil }
        var holes: [Wire] = []
        for hole in shape.holes {
            guard let w = wire(for: hole) else { return nil }
            holes.append(w)
        }
        guard let face = Shape.face(outer: outer, holes: holes) else { return nil }
        return DXFContourFace(face: face, outerWire: outer, holeWires: holes, contour: shape)
    }
}
