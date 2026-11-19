// DrawingResult.swift
// OCCTSwiftIO
//
// What `DrawingLoader.read(from:)` returns, whatever the file format.

import Foundation
@_exported import SwiftDXF

/// A drawing read from any supported format, with where it came from and what was left out.
public struct DrawingResult: Sendable {
    /// The drawing, in one entity model for every format: entities with layers, units and
    /// extents (hatches and leaders are entities), plus block references and the layer and line type
    /// tables.
    ///
    /// `drawing.identities[i]` identifies `drawing.entities[i]`.
    public var drawing: DXF.Drawing
    public var source: DrawingSource
    /// What was skipped by type and layer, could not be read, or was assumed.
    public var warnings: [DrawingWarning]
    /// The dimensions the reader rebuilt from loose pieces, rather than read as dimensions stored
    /// in the file, each with the pieces it was built from.
    ///
    /// A `.dimension` entity whose identity is not here was stored in the file as a dimension.
    /// Only a JWW has rebuilt dimensions so far; for a DXF or a DWG this is empty.
    public var rebuiltDimensions: [RebuiltDimension]
    /// The dimension values of a JWW that are not a `.dimension` in the drawing.
    ///
    /// A value is a top-level text marked with Jw_cad's dimension flags, or the value of a
    /// dimension record that stores no measured points. Each stays in the drawing as a loose text,
    /// and has a ``DrawingWarning/Kind/unexplainedDimensionValue`` warning.
    public var unexplainedDimensionValues: [UnexplainedDimensionValue]
    /// The scale of each JWW layer group that holds part of the drawing.
    ///
    /// The reader has multiplied each one out, so the drawing is at full size. Empty for a DXF or
    /// a DWG.
    public var layerGroupScales: [LayerGroupScale]

    public init(
        drawing: DXF.Drawing, source: DrawingSource, warnings: [DrawingWarning],
        rebuiltDimensions: [RebuiltDimension] = [],
        unexplainedDimensionValues: [UnexplainedDimensionValue] = [],
        layerGroupScales: [LayerGroupScale] = []
    ) {
        self.drawing = drawing
        self.source = source
        self.warnings = warnings
        self.rebuiltDimensions = rebuiltDimensions
        self.unexplainedDimensionValues = unexplainedDimensionValues
        self.layerGroupScales = layerGroupScales
    }
}

extension DrawingResult {
    /// A dimension the reader built from loose pieces, not one stored in the file as a dimension.
    public struct RebuiltDimension: Sendable, Equatable {
        /// The identity of the `.dimension` entity in ``DrawingResult/drawing``.
        public var identity: DXF.Identity
        /// The loose pieces the dimension was built from, in file order.
        ///
        /// A piece can belong to more than one dimension: a chain of dimensions shares one
        /// dimension line, and neighbours share an arrow point and an extension line.
        public var pieces: [Piece]

        public init(identity: DXF.Identity, pieces: [Piece] = []) {
            self.identity = identity
            self.pieces = pieces
        }

        /// One loose element of the file that a rebuilt dimension was built from.
        public struct Piece: Sendable, Equatable {
            /// What the piece is in the dimension.
            public enum Kind: String, Sendable, Equatable {
                /// The text that states the value, such as `1,930`.
                case valueText
                /// Another copy of the value text, stored at the same place.
                case valueTextCopy
                /// One of the two points the dimension measures between.
                case arrowPoint
                /// A line parallel to the dimension, which can run past the arrow points.
                case dimensionLine
                /// A line at an angle to the dimension, which ends on an arrow point.
                case extensionLine
            }

            public var kind: Kind
            /// Where the piece is, at full size: both ends of a line, the one point of an arrow
            /// point, and the insertion point of a value text.
            public var points: [DXF.Point]
            /// The layer it is on, such as `0-E`.
            public var layer: String
            /// The index of the element in the JWW file's top-level elements.
            public var elementIndex: Int

            public init(kind: Kind, points: [DXF.Point], layer: String, elementIndex: Int) {
                self.kind = kind
                self.points = points
                self.layer = layer
                self.elementIndex = elementIndex
            }
        }
    }

    /// A dimension value that is not a `.dimension` in the drawing, kept as a loose text.
    public struct UnexplainedDimensionValue: Sendable, Equatable {
        /// The value as written, such as `1,930` or `R5`.
        public var text: String
        /// Where the text is, at full size.
        public var position: DXF.Point
        /// The layer it is on, such as `0-E`.
        public var layer: String

        public init(text: String, position: DXF.Point, layer: String) {
            self.text = text
            self.position = position
            self.layer = layer
        }
    }

    /// The scale a JWW layer group was drawn at.
    public struct LayerGroupScale: Sendable, Equatable {
        /// The group number, 0 to 15.
        public var group: Int
        /// The scale denominator the group's lengths were multiplied by.
        ///
        /// It is 80 for a group drawn at 1:80, and 1 for a group that states no usable scale,
        /// which has a ``DrawingWarning/Kind/scaleNotStated`` warning.
        public var scale: Double

        public init(group: Int, scale: Double) {
            self.group = group
            self.scale = scale
        }

        /// The start of the names of the group's layers, such as `0-`.
        ///
        /// A JWW layer is named `<group>-<layer>` in hexadecimal, so the layers of group 0 are
        /// `0-0` to `0-F`. The members of an expanded block keep their own layers but take the
        /// scale of the group of the reference that places them.
        public var layerNamePrefix: String { String(group, radix: 16, uppercase: true) + "-" }
    }
}
