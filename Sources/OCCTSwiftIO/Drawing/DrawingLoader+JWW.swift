// DrawingLoader+JWW.swift
// OCCTSwiftIO
//
// A JWW read at full size, with the dimensions SwiftJWW rebuilds from loose pieces, and what the DXF
// text cannot say: which dimensions were rebuilt, which values were not explained, and the scale of
// each layer group.

import Foundation
import SwiftJWW

extension DrawingLoader {

    /// A JWW drawing in the shared model, with what only the JWW knows.
    struct JWWRead {
        var drawing: DXF.Drawing
        var version: String
        var rebuiltDimensions: [DrawingResult.RebuiltDimension]
        var unexplainedDimensionValues: [DrawingResult.UnexplainedDimensionValue]
        var layerGroupScales: [DrawingResult.LayerGroupScale]
        /// The warnings only a JWW gives: scales and unexplained values.
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
    /// `<group>-<layer>`. Its report gives the handles of the dimensions it rebuilt, which survive
    /// the parse as the entities' identities, and the indices of the values it could not explain,
    /// which are read from the `JWW.Drawing`.
    static func readJWW(_ data: Data, options: DXF.ReadOptions) throws -> JWWRead {
        let jww = try JWW.read(data: data)
        let output = DXFWriter.output(jww, options: jwwWriterOptions)
        let drawing = try DXF.read(text: output.text, options: options)

        let reported = Set(output.report.recoveredDimensions)
        var rebuilt: [DrawingResult.RebuiltDimension] = []
        for (index, entity) in drawing.entities.enumerated() {
            guard case .dimension = entity, drawing.identities.indices.contains(index) else {
                continue
            }
            let identity = drawing.identities[index]
            if let handle = identity.handle, reported.contains(handle) {
                rebuilt.append(DrawingResult.RebuiltDimension(identity: identity))
            }
        }

        let scales = layerGroupScales(of: jww)
        let (unexplained, valueWarnings) = unexplainedValues(
            jww: jww, unmatched: output.report.unexplainedValues)

        var warnings = scaleWarnings(jww: jww, scales: scales) + valueWarnings
        if jww.counts.solid > 0 {
            // SwiftJWW reads a solid fill's place in the file but not the fill, and not its layer.
            let count = jww.counts.solid
            warnings.append(
                DrawingWarning(
                    kind: .skippedEntities, type: "SOLID", count: count,
                    message: "\(count) SOLID entities were not read"))
        }

        return JWWRead(
            drawing: drawing, version: String(jww.version), rebuiltDimensions: rebuilt,
            unexplainedDimensionValues: unexplained, layerGroupScales: scales, warnings: warnings)
    }

    /// The dimension values that are not a `DIMENSION` in the drawing, in file order, with a
    /// warning for each.
    ///
    /// Two kinds: the value texts SwiftJWW could not pair with arrow points (`unmatched`, indices
    /// into the elements), and the values of dimension records that store no measured points (a
    /// file older than version 4.20), which SwiftJWW's writer leaves as a loose line and text.
    static func unexplainedValues(
        jww: JWW.Drawing, unmatched: [Int]
    ) -> ([DrawingResult.UnexplainedDimensionValue], [DrawingWarning]) {
        var found: [(index: Int, text: String, at: JWW.Point, layer: Int, reason: String)] = []
        for index in unmatched where jww.elements.indices.contains(index) {
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
            let factor = appliedScale(jww.scale(ofLayerGroup: group))
            let value = DrawingResult.UnexplainedDimensionValue(
                text: entry.text, position: DXF.Point(entry.at.x * factor, entry.at.y * factor),
                layer: layerName(group: group, layer: entry.layer))
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

    /// The scale of each layer group that holds a top-level element, in group order.
    ///
    /// A block's members follow the insert that places them, so the top-level elements name every
    /// group whose scale was applied.
    static func layerGroupScales(of jww: JWW.Drawing) -> [DrawingResult.LayerGroupScale] {
        let used = Set(jww.elements.map(\.attributes.layerGroup))
        return used.sorted().map { group in
            DrawingResult.LayerGroupScale(
                group: group, scale: appliedScale(jww.scale(ofLayerGroup: group)))
        }
    }

    /// The warnings about scale: a group in use that states none, and groups at different scales.
    ///
    /// The scales compared are the factors applied, so a group read at drawn size beside a scaled
    /// one is a mixed scale too.
    static func scaleWarnings(
        jww: JWW.Drawing, scales: [DrawingResult.LayerGroupScale]
    ) -> [DrawingWarning] {
        var out: [DrawingWarning] = []
        var described: [String] = []
        for entry in scales {
            if isUsable(jww.scale(ofLayerGroup: entry.group)) {
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

    /// The factor SwiftJWW's writer applies for a group's stated scale: the scale when it is usable,
    /// otherwise 1.
    static func appliedScale(_ stated: Double?) -> Double {
        guard let stated, isUsable(stated) else { return 1 }
        return stated
    }

    private static func isUsable(_ scale: Double?) -> Bool {
        guard let scale else { return false }
        return scale.isFinite && scale > 0
    }

    /// A JWW layer's name as SwiftJWW's writer gives it: group and layer in hexadecimal, `0-E`.
    static func layerName(group: Int, layer: Int) -> String {
        DrawingResult.LayerGroupScale.layerNamePrefix(ofGroup: group)
            + String(layer, radix: 16, uppercase: true)
    }

    /// A number for a message: whole numbers without a decimal point.
    private static func number(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15
            ? String(Int64(value)) : String(format: "%.3f", value)
    }
}
