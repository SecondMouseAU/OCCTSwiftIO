// DrawingLoader+Skipped.swift
// OCCTSwiftIO
//
// What a reader left out, as warnings: entities of a type with no entity form, and what SwiftDWG
// could not read.

import Foundation
import SwiftDXF

extension DrawingLoader {

    static let emptyDrawingMessage = "the drawing has no entities"

    /// What SwiftDWG puts before the type of something it could not read, in `skipped`.
    ///
    /// SwiftDWG's README documents the prefix and the table names below but does not export them,
    /// so a release that renames them would turn `.unreadable` into `.skippedEntities`; the tests
    /// that damage a DWG would show it.
    static let unreadablePrefix = "UNREADABLE_"

    /// The tables whose records SwiftDWG counts when it cannot read one.
    private static let tablesWithUnreadableRecords: Set<String> = [
        "LAYER", "LTYPE", "STYLE", "DIMSTYLE", "BLOCK_RECORD",
    ]

    /// Entities of a type with no entity form, by type and layer, or by type alone when the layer
    /// is not known.
    static func skippedWarnings(for drawing: DXF.Drawing, layersKnown: Bool) -> [DrawingWarning] {
        var out: [DrawingWarning] = []
        for type in drawing.skippedByLayer.keys.sorted() where !type.hasPrefix(unreadablePrefix) {
            let byLayer = drawing.skippedByLayer[type] ?? [:]
            guard layersKnown else {
                let count = byLayer.values.reduce(0, +)
                out.append(
                    DrawingWarning(
                        kind: .skippedEntities, type: type, count: count,
                        message: "\(count) \(type) entities were not read"))
                continue
            }
            for (layer, count) in byLayer.sorted(by: { $0.key < $1.key }) {
                out.append(
                    DrawingWarning(
                        kind: .skippedEntities, type: type, layer: layer, count: count,
                        message: "\(count) \(type) entities on layer \(layer) were not read"))
            }
        }
        return out
    }

    /// What the reader found in the file and could not read, one warning per type.
    ///
    /// The count covers model space (paper space too, whether or not it was left out) and the
    /// blocks that were expanded into it, once for each
    /// reference that expanded the block. The block definitions are counted when they were not
    /// expanded; with expansion on, one that nothing inserts is not part of the drawing, and is
    /// not counted.
    static func unreadableWarnings(
        for drawing: DXF.Drawing, expandedBlocks: Bool, leftOutPaperSpace: Bool = false
    ) -> [DrawingWarning] {
        var drawn: [String: Int] = [:]
        var inBlocks: [String: Int] = [:]
        for (type, byLayer) in drawing.skippedByLayer where type.hasPrefix(unreadablePrefix) {
            drawn[type, default: 0] += byLayer.values.reduce(0, +)
        }
        if leftOutPaperSpace {
            // Left out before they were counted as skipped, but still tallied as paper space.
            for (type, count) in drawing.paperSpace where type.hasPrefix(unreadablePrefix) {
                drawn[type, default: 0] += count
            }
        }
        if !expandedBlocks {
            for block in drawing.blocks {
                for (type, byLayer) in block.skippedByLayer where type.hasPrefix(unreadablePrefix) {
                    inBlocks[type, default: 0] += byLayer.values.reduce(0, +)
                }
            }
        }
        return Set(drawn.keys).union(inBlocks.keys).sorted().map { key in
            let type = String(key.dropFirst(unreadablePrefix.count))
            let blocks = inBlocks[key, default: 0]
            let count = drawn[key, default: 0] + blocks
            let subject: String
            if type == "OBJECT" {
                subject = "objects"
            } else if tablesWithUnreadableRecords.contains(type) {
                subject = "\(type) table records"
            } else {
                subject = "\(type) entities"
            }
            return DrawingWarning(
                kind: .unreadable, type: type, count: count,
                message: "\(subject): \(count) could not be read"
                    + (blocks > 0 ? " (\(blocks) in block definitions)" : ""))
        }
    }
}
