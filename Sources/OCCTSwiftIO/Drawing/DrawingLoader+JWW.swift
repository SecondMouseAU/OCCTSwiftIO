// DrawingLoader+JWW.swift
// OCCTSwiftIO
//
// A JWW read at full size, with the dimensions SwiftJWW rebuilds from loose pieces, and what the DXF
// text cannot say: which dimensions were rebuilt and from which pieces, which values were not
// explained, and the scale of each layer group.

import Foundation
import SwiftJWW

private typealias Piece = DrawingResult.RebuiltDimension.Piece

extension DrawingLoader {

    /// A JWW drawing in the shared model, with what only the JWW knows.
    struct JWWRead {
        var drawing: DXF.Drawing
        var version: String
        var rebuiltDimensions: [DrawingResult.RebuiltDimension]
        var unexplainedDimensionValues: [DrawingResult.UnexplainedDimensionValue]
        var layerGroupScales: [DrawingResult.LayerGroupScale]
        /// The warnings only a JWW gives: scales, unexplained values and skipped solid fills.
        ///
        /// The warnings every format gives come from
        /// ``warnings(for:expandedBlocks:layersKnown:leftOutPaperSpace:)``.
        var warnings: [DrawingWarning]
    }

    /// How SwiftJWW's writer is asked to write a JWW for this package: at full size, with the
    /// dimensions it rebuilds from loose pieces written as `DIMENSION`s.
    static let jwwWriterOptions = DXFWriter.Options(fullSize: true, recoversDimensions: true)

    /// Read a JWW through SwiftJWW's DXF writer and SwiftDXF.
    ///
    /// The writer multiplies each element by its layer group's scale and names each layer
    /// `<group>-<layer>`. Its report gives the scale it applied to each group, the handles of the
    /// dimensions it rebuilt, which survive the parse as the entities' identities, the elements
    /// each was built from, and the indices of the values it could not explain; the elements are
    /// read from the `JWW.Drawing`.
    static func readJWW(_ data: Data, options: DXF.ReadOptions) throws -> JWWRead {
        let jww = try JWW.read(data: data)
        let output = DXFWriter.output(jww, options: jwwWriterOptions)
        let drawing = try DXF.read(text: output.text, options: options)
        let report = output.report

        var rebuilt: [DrawingResult.RebuiltDimension] = []
        for (index, entity) in drawing.entities.enumerated() {
            guard case .dimension(let dimension) = entity,
                drawing.identities.indices.contains(index)
            else { continue }
            let identity = drawing.identities[index]
            guard let handle = identity.handle,
                let elements = report.recoveredDimensionElements[handle]
            else { continue }
            // A DIMENSION with no rotation (group 50) is horizontal, as DXF defines it.
            let pieces = rebuiltPieces(
                elements, rotation: dimension.rotation ?? 0, jww: jww, report: report)
            rebuilt.append(DrawingResult.RebuiltDimension(identity: identity, pieces: pieces))
        }

        let scales = report.appliedScales.sorted { $0.key < $1.key }.map {
            DrawingResult.LayerGroupScale(group: $0.key, scale: $0.value)
        }
        let (unexplained, valueWarnings) = unexplainedValues(jww: jww, report: report)

        var warnings = scaleWarnings(jww: jww, scales: scales) + valueWarnings
        if let solids = skippedSolidWarning(jww: jww, expandedBlocks: options.expandBlocks) {
            warnings.append(solids)
        }

        return JWWRead(
            drawing: drawing, version: String(jww.version), rebuiltDimensions: rebuilt,
            unexplainedDimensionValues: unexplained, layerGroupScales: scales, warnings: warnings)
    }

    /// The warning for the solid fills SwiftJWW skipped, counted as the `unreadable` warning
    /// counts: once for each placement of a block when blocks are expanded, and when they are not,
    /// once in each block definition, which the message says.
    static func skippedSolidWarning(jww: JWW.Drawing, expandedBlocks: Bool) -> DrawingWarning? {
        let inDefinitions = jww.skippedSolidCount - jww.counts.solid
        let count: Int
        var note = ""
        if !expandedBlocks {
            count = jww.skippedSolidCount
            if inDefinitions > 0 { note = " (\(inDefinitions) in block definitions)" }
        } else if inDefinitions > 0 {
            count = jww.expandingBlocks().solidCount
        } else {
            count = jww.counts.solid  // no fill in a block, so nothing to expand
        }
        guard count > 0 else { return nil }
        // SwiftJWW reads a solid fill's place in the file but not the fill, and not its layer.
        return DrawingWarning(
            kind: .skippedEntities, type: "SOLID", count: count,
            message: "\(count) SOLID entities were not read" + note)
    }

    /// The sine of the angle below which a line is parallel to a dimension, the threshold SwiftJWW's
    /// recovery uses to tell a dimension line from an extension line.
    private static let parallelSine = 1e-3

    /// The pieces of a rebuilt dimension: the elements the writer's report lists for it, at full
    /// size, in file order.
    ///
    /// A line is a dimension line when it is parallel to the dimension, whose direction is
    /// `rotation` degrees from the x axis, and an extension line otherwise.
    private static func rebuiltPieces(
        _ indices: [Int], rotation: Double, jww: JWW.Drawing, report: DXFWriter.Report
    ) -> [Piece] {
        let angle = rotation * .pi / 180
        let direction = (x: cos(angle), y: sin(angle))
        var pieces: [Piece] = []
        for index in indices where jww.elements.indices.contains(index) {
            let element = jww.elements[index]
            // A copy of the value is found after the value, so it comes later in the file.
            let afterValue = pieces.contains { $0.kind == .valueText }
            if let piece = piece(
                element, index: index,
                factor: report.appliedScales[element.attributes.layerGroup] ?? 1,
                direction: direction, afterValue: afterValue)
            {
                pieces.append(piece)
            }
        }
        return pieces
    }

    /// One element of a rebuilt dimension as a piece, multiplied by `factor` and on the layer the
    /// writer names; nil for an element that is not a text, a point or a line.
    private static func piece(
        _ element: JWW.Element, index: Int, factor: Double, direction: (x: Double, y: Double),
        afterValue: Bool
    ) -> Piece? {
        func full(_ point: JWW.Point) -> DXF.Point { DXF.Point(point.x * factor, point.y * factor) }
        func named(_ layer: Int) -> String {
            DXFWriter.layerName(group: element.attributes.layerGroup, layer: layer)
        }
        switch element.entity {
        case .text(let at, _, _, _, _, let layer, _):
            return Piece(
                kind: afterValue ? .valueTextCopy : .valueText, points: [full(at)],
                layer: named(layer), elementIndex: index)
        case .point(let at, let layer, _):
            return Piece(
                kind: .arrowPoint, points: [full(at)], layer: named(layer), elementIndex: index)
        case .line(let a, let b, let layer, _):
            let length = hypot(b.x - a.x, b.y - a.y)
            let cross = abs((b.x - a.x) * direction.y - (b.y - a.y) * direction.x)
            let isParallel = length == 0 || cross / length < parallelSine
            return Piece(
                kind: isParallel ? .dimensionLine : .extensionLine, points: [full(a), full(b)],
                layer: named(layer), elementIndex: index)
        default:
            return nil
        }
    }

    /// The dimension values that are not a `DIMENSION` in the drawing, in file order, with a
    /// warning for each.
    ///
    /// Two kinds: the value texts SwiftJWW could not pair with arrow points (the report's
    /// `unexplainedValues`, indices into the elements), and the values of dimension records that
    /// store no measured points (a file older than version 4.20), which SwiftJWW's writer leaves
    /// as a loose line and text.
    static func unexplainedValues(
        jww: JWW.Drawing, report: DXFWriter.Report
    ) -> ([DrawingResult.UnexplainedDimensionValue], [DrawingWarning]) {
        var found: [(index: Int, text: String, at: JWW.Point, layer: Int, reason: String)] = []
        for index in report.unexplainedValues where jww.elements.indices.contains(index) {
            let element = jww.elements[index]
            if case .text(let at, _, _, _, let string, _, _) = element.entity {
                found.append(
                    (
                        index, string, at, element.attributes.layer,
                        "is not explained by any dimension, so it is kept as text"
                    ))
            }
        }
        for (index, element) in jww.elements.enumerated() {
            // The writer leaves such a record's parts loose, each on its own layer.
            guard let record = element.dimension, record.measuredPoints.count != 2,
                case .dimension(let parts, _) = element.entity,
                let text = parts.first(where: { if case .text = $0 { true } else { false } }),
                case .text(_, _, _, _, _, let layer, _) = text
            else { continue }
            found.append(
                (
                    index, record.label.string, record.label.at, layer,
                    "belongs to a dimension record that stores no measured points (a file older "
                        + "than version 4.20), so it is kept as a line and text"
                ))
        }

        var values: [DrawingResult.UnexplainedDimensionValue] = []
        var warnings: [DrawingWarning] = []
        for entry in found.sorted(by: { $0.index < $1.index }) {
            let group = jww.elements[entry.index].attributes.layerGroup
            let factor = report.appliedScales[group] ?? 1
            let value = DrawingResult.UnexplainedDimensionValue(
                text: entry.text, position: DXF.Point(entry.at.x * factor, entry.at.y * factor),
                layer: DXFWriter.layerName(group: group, layer: entry.layer))
            values.append(value)
            warnings.append(
                DrawingWarning(
                    kind: .unexplainedDimensionValue, type: "TEXT", layer: value.layer,
                    message: "the dimension value \(entry.text) on layer \(value.layer) at "
                        + "(\(number(value.position.x)), \(number(value.position.y))) "
                        + entry.reason))
        }
        return (values, warnings)
    }

    /// The warnings about scale: a group in use that states none, and groups at different scales.
    ///
    /// The scales compared are the factors applied, so a group read at drawn size beside a scaled
    /// one is a mixed scale too. A group states no usable scale when the writer applied something
    /// other than its stated scale, since the writer falls back to 1 only then.
    static func scaleWarnings(
        jww: JWW.Drawing, scales: [DrawingResult.LayerGroupScale]
    ) -> [DrawingWarning] {
        var out: [DrawingWarning] = []
        var described: [String] = []
        for entry in scales {
            if jww.scale(ofLayerGroup: entry.group) == entry.scale {
                described.append("1:\(number(entry.scale)) for group \(entry.group)")
            } else {
                described.append("drawn size for group \(entry.group)")
                out.append(
                    DrawingWarning(
                        kind: .scaleNotStated, layer: entry.layerNamePrefix,
                        message: "layer group \(entry.group) states no scale, so it was read at "
                            + "drawn size"))
            }
        }
        let distinct = Set(scales.map(\.scale))
        if distinct.count > 1 {
            out.append(
                DrawingWarning(
                    kind: .mixedScales, count: distinct.count,
                    message: "the layer groups are at different scales ("
                        + described.joined(separator: ", ") + "); each is at full size, so they "
                        + "are no longer placed relative to each other as on the sheet"))
        }
        return out
    }

    /// A number for a message: whole numbers without a decimal point.
    private static func number(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15
            ? String(Int64(value)) : String(format: "%.3f", value)
    }
}
