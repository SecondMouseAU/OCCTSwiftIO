// DrawingWarning.swift
// OCCTSwiftIO
//
// What a read dropped or assumed, as data a consumer can show and never has to guess.

import Foundation

/// One thing about a drawing read that a consumer should not miss.
public struct DrawingWarning: Sendable, Equatable, CustomStringConvertible {
    public enum Kind: String, Sendable, Equatable {
        /// Entities of a type with no entity form were not read, by type and layer.
        case skippedEntities
        /// Entities flagged as paper space were read, or left out when asked.
        case paperSpaceEntities
        /// A block reference names a block the file does not define.
        case missingBlock
        /// A block contains itself.
        case blockCycle
        /// Block nesting went past the limit.
        case blockNestingTooDeep
        /// Entities a non-uniform scale could not carry exactly were dropped.
        case notTransformed
        /// References with an extrusion not along z were expanded flat.
        case unsupportedExtrusion
        /// Entities of a type, with an extrusion not along z, were read as if it were.
        case extrusionNotApplied
        /// Block expansion stopped at its size limit, so some references are not expanded.
        case expansionTruncated
        /// The file declares no length unit.
        case unitsNotDeclared
        /// Nothing was read.
        case emptyDrawing
        /// The reader found something in the file that it could not read, so it is not in the
        /// drawing: an entity, a table record or a block, by type.
        ///
        /// Of a DWG only. ``type`` is the DXF type name (`LINE`, `POLYLINE`, `LAYER`,
        /// `BLOCK_RECORD`), or `OBJECT` for one whose type is itself unreadable. An entity of a
        /// block that was expanded counts once for each reference.
        case unreadable
        /// A JWW layer group in use states no scale, so it was read at drawn size.
        case scaleNotStated
        /// The JWW layer groups in use have different scales; ``count`` is how many.
        case mixedScales
        /// A JWW dimension value that is not a dimension in the drawing, one per value.
        case unexplainedDimensionValue
        /// Entities were read but no edge comes of them, so they are not in the compound
        /// `ShapeLoader` returns: `TEXT`, `DIMENSION`, `HATCH`, `LEADER`, `TOLERANCE`, `SOLID`,
        /// `WIPEOUT` or `3DFACE`, by type and layer.
        ///
        /// `ShapeLoader` only: `DrawingLoader` returns the entities themselves.
        case noEdges
        /// Geometry with no size makes no edge: a line with equal end points, a circle or arc with
        /// no positive radius, a polyline with no vertices or a segment between equal points, a
        /// spline or ellipse that fits to no lines or arcs, by type and layer. `ShapeLoader` only;
        /// ``count`` is entities, or segments for a polyline.
        case degenerate
        /// Geometry with a size made no edge, because OCCT would not make one (a line with an
        /// infinite coordinate), by type and layer. Without a type, edges were made and OCCT could
        /// not join them into a compound. `ShapeLoader` only.
        case notBuilt
    }

    public var kind: Kind
    /// The entity type, for the kinds that concern one.
    public var type: String?
    /// The layer, for ``Kind/skippedEntities``, ``Kind/unexplainedDimensionValue`` and the kinds
    /// of the shapes path (``Kind/noEdges``, ``Kind/degenerate``, ``Kind/notBuilt``), or the prefix
    /// of a layer group's layer names, for ``Kind/scaleNotStated``; `nil` when the format does not
    /// say.
    ///
    /// A DWG's skipped entities, and a JWW's solid fills, are counted without their layer, so it is
    /// `nil` for them. The entities of the shapes path's kinds were read, so each has its layer.
    public var layer: String?
    /// How many, in the unit the kind counts: entities, except that the shapes path's
    /// ``Kind/degenerate`` and ``Kind/notBuilt`` count a polyline's segments and a fit's pieces.
    public var count: Int
    public var message: String

    public init(
        kind: Kind, type: String? = nil, layer: String? = nil, count: Int = 1, message: String
    ) {
        self.kind = kind
        self.type = type
        self.layer = layer
        self.count = count
        self.message = message
    }

    public var description: String { message }
}
