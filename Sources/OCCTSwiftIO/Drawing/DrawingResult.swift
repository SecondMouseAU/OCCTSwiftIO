// DrawingResult.swift
// OCCTSwiftIO
//
// What `DrawingLoader.read(from:)` returns, whatever the file format.

import Foundation
@_exported import SwiftDXF

/// A drawing read from any supported format, with where it came from and what was left out.
public struct DrawingResult: Sendable {
    /// The drawing, in one entity model for every format: entities with layers, units and
    /// extents, plus block references, hatches, leaders and the layer and line type tables.
    ///
    /// `drawing.identities[i]` identifies `drawing.entities[i]`.
    public var drawing: DXF.Drawing
    public var source: DrawingSource
    /// What was skipped by type and layer, assumed or reported by a converter.
    public var warnings: [DrawingWarning]

    public init(drawing: DXF.Drawing, source: DrawingSource, warnings: [DrawingWarning]) {
        self.drawing = drawing
        self.source = source
        self.warnings = warnings
    }
}
