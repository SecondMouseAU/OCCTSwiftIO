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
        /// The file declares no length unit.
        case unitsNotDeclared
        /// Nothing was read.
        case emptyDrawing
        /// A converter reported a problem.
        case converter
    }

    public var kind: Kind
    /// The entity type, for the kinds that concern one.
    public var type: String?
    /// The layer, for ``Kind/skippedEntities``.
    public var layer: String?
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
