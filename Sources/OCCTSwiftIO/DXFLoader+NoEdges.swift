// DXFLoader+NoEdges.swift
// OCCTSwiftIO
//
// What the shapes path read and made no edge from: annotation, fills, masks and 3D faces. They are
// in the drawing SwiftDXF built, so `DrawingLoader` returns them, but `ShapeLoader` returns only
// edges, and a consumer that loads a drawing for its geometry should be told what it did not get.

import SwiftDXF

extension DXFLoader {

    /// The entities of a drawing that no edge comes of, counted by type and layer as the shapes
    /// path goes through it.
    struct NoEdgeTally {
        private struct Key: Hashable {
            var type: String
            var layer: String
        }

        private var counts: [Key: Int] = [:]

        /// Counts `entity` when the shapes path makes no edge of it, and does nothing for one it
        /// does.
        ///
        /// This switch and the one in `DXFLoader.shapes(of:layersKnown:)` are exhaustive on
        /// purpose: a `DXF.Entity` case a later SwiftDXF adds does not compile until someone says
        /// whether it has edges.
        mutating func add(_ entity: DXF.Entity) {
            switch entity {
            case .line, .circle, .arc, .ellipse, .point, .polyline, .spline:
                return
            case .text(_, _, _, _, let layer, _):
                add("TEXT", layer: layer)
            case .dimension(let dimension):
                add("DIMENSION", layer: dimension.layer)
            case .hatch(let hatch):
                add("HATCH", layer: hatch.layer)
            case .leader(let leader):
                add("LEADER", layer: leader.layer)
            case .tolerance(let tolerance):
                add("TOLERANCE", layer: tolerance.layer)
            case .solid(let solid):
                add("SOLID", layer: solid.layer)
            case .wipeout(let wipeout):
                add("WIPEOUT", layer: wipeout.layer)
            case .face3D(let face):
                add("3DFACE", layer: face.layer)
            }
        }

        private mutating func add(_ type: String, layer: String) {
            counts[Key(type: type, layer: layer), default: 0] += 1
        }

        /// One warning for each type and layer, in order of type and then layer.
        var warnings: [DrawingWarning] {
            counts.sorted { ($0.key.type, $0.key.layer) < ($1.key.type, $1.key.layer) }.map {
                entry in
                let (type, layer) = (entry.key.type, entry.key.layer)
                return DrawingWarning(
                    kind: .noEdges, type: type, layer: layer, count: entry.value,
                    message:
                        "\(entry.value) \(type) entities on layer \(layer) were read but have no "
                        + "edges, so they are not in the compound")
            }
        }
    }
}
