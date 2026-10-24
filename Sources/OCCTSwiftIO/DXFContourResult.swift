// DXFContourResult.swift
// OCCTSwiftIO
//
// The OCCT-side result of `DXFLoader.loadContours`: one planar face per SwiftDXF contour shape,
// plus the SwiftDXF diagnostics passed through as data.

import Foundation
import OCCTSwift
import SwiftDXF

/// A planar face built from one SwiftDXF contour shape (an outer loop and its holes).
public struct DXFContourFace: @unchecked Sendable {
    /// The face in the Z=0 plane, holes subtracted.
    public let face: Shape
    /// The outer boundary, counter-clockwise seen from +Z.
    public let outerWire: Wire
    /// The hole boundaries, one per hole of ``contour``.
    public let holeWires: [Wire]
    /// The SwiftDXF shape this face was built from (segments, layers, analytic area).
    public let contour: DXF.Contour.Shape

    /// Analytic area in square millimetres: outer area minus the holes.
    public var area: Double { contour.area }
}

/// The outcome of ``DXFLoader/loadContours(from:options:)``.
///
/// Geometry is in millimetres, in the Z=0 plane. `warnings`, `openChains` and the unit fields are
/// SwiftDXF's own results, passed through unchanged.
public struct DXFContourResult: @unchecked Sendable {
    /// One face per contour shape, largest outer area first.
    public var faces: [DXFContourFace]
    /// Contour shapes OCCT could not turn into a face.
    ///
    /// Empty in normal use.
    public var unbuilt: [DXF.Contour.Shape]
    /// Segments that never closed into a loop.
    public var openChains: [DXF.Contour.Chain]
    /// What SwiftDXF dropped, assumed or approximated.
    public var warnings: [DXF.Contour.Warning]
    /// The unit the drawing was read in.
    public var unit: DXF.Contour.LengthUnit
    /// Millimetres per drawing unit applied to every coordinate.
    public var unitScale: Double
    /// Largest distance between a fitted line or arc and the ellipse or spline it replaces.
    public var maxFitDeviation: Double

    /// The faces as a ``ShapeLoadResult`` (one shape per face, no color), for `ShapeLoader` consumers.
    public var shapeLoadResult: ShapeLoadResult {
        ShapeLoadResult(shapesWithColors: faces.map { (shape: $0.face, color: nil) })
    }
}
