// DXFLoader+Dropped.swift
// OCCTSwiftIO
//
// What the shapes path could not make an edge of, though it is a drawable entity: geometry with no
// size, and geometry OCCT or the curve fit would not turn into an edge. Counted as the loader goes,
// so that nothing it drops is dropped without a word.

import SwiftDXF

extension DXFLoader {

    /// The drawable geometry the shapes path made no edge of, counted by cause, type and layer.
    struct DroppedTally {

        /// Why no edge was made.
        enum Cause: String {
            case noLength, noRadius, noVertices, notBuilt, noFit

            /// `.degenerate` when the drawing's own numbers give it no size, which includes a fit
            /// that gives no pieces (SwiftDXF returns none for degenerate input); `.notBuilt` when
            /// they have a size and OCCT would not make an edge of them.
            var kind: DrawingWarning.Kind {
                switch self {
                case .noLength, .noRadius, .noVertices, .noFit: return .degenerate
                case .notBuilt: return .notBuilt
                }
            }

            var reason: String {
                switch self {
                case .noLength: return "have no length"
                case .noRadius: return "have no positive radius"
                case .noVertices: return "have no vertices"
                case .notBuilt: return "gave no edge, as OCCT would not make one"
                case .noFit: return "gave no pieces when fitted to lines and arcs"
                }
            }
        }

        /// What was counted: a whole entity, one segment of a polyline, or one piece of a fit.
        enum Unit: String {
            case entities, segments, pieces
        }

        private struct Key: Hashable {
            var cause: Cause
            var type: String
            var layer: String
            var unit: Unit
        }

        private var counts: [Key: Int] = [:]
        /// Edges that were made and could not be joined into a compound, which loses all of them.
        private(set) var unjoined = 0

        mutating func add(_ cause: Cause, type: String, layer: String, unit: Unit = .entities) {
            counts[Key(cause: cause, type: type, layer: layer, unit: unit), default: 0] += 1
        }

        mutating func addUnjoined(_ count: Int) {
            unjoined += count
        }

        /// One warning for each type, layer, cause and unit, in that order, then one for a compound
        /// that could not be made.
        var warnings: [DrawingWarning] {
            let sorted = counts.sorted {
                ($0.key.type, $0.key.layer, $0.key.cause.rawValue, $0.key.unit.rawValue)
                    < ($1.key.type, $1.key.layer, $1.key.cause.rawValue, $1.key.unit.rawValue)
            }
            var out = sorted.map { entry -> DrawingWarning in
                let key = entry.key
                return DrawingWarning(
                    kind: key.cause.kind, type: key.type, layer: key.layer, count: entry.value,
                    message:
                        "\(entry.value) \(key.type) \(key.unit.rawValue) on layer \(key.layer) "
                        + "\(key.cause.reason), so they are not in the compound")
            }
            if unjoined > 0 {
                out.append(
                    DrawingWarning(
                        kind: .notBuilt, count: unjoined,
                        message:
                            "\(unjoined) edges were made but OCCT could not join them into a "
                            + "compound, so none is returned"))
            }
            return out
        }
    }
}
