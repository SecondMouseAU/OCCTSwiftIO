// DrawingLoader.swift
// OCCTSwiftIO
//
// One entry point for 2D drawing import. DXF is read directly, DWG through the `dwg2dxf`
// converter, and JWW through SwiftJWW's DXF writer, and all three come back as the same
// `DXF.Drawing`, so a consumer neither picks a reader nor branches on the file extension.

import Foundation
import SwiftJWW

#if canImport(CryptoKit)
    import CryptoKit
#endif

public enum DrawingLoader {

    /// Settings for ``read(from:options:)``.
    public struct Options: Sendable {
        /// Flatten block references into the entities, hatches and leaders.
        ///
        /// The references are recorded in each identity's `via`. On by default.
        public var expandBlocks: Bool
        /// Leave paper-space entities out, as a model-space read does.
        public var skipPaperSpace: Bool
        /// The `dwg2dxf` executable for DWG; `nil` finds it through `OCCTSWIFTIO_DWG2DXF` or
        /// `PATH`.
        public var converter: URL?

        public init(expandBlocks: Bool = true, skipPaperSpace: Bool = false, converter: URL? = nil)
        {
            self.expandBlocks = expandBlocks
            self.skipPaperSpace = skipPaperSpace
            self.converter = converter
        }
    }

    public enum LoadError: Error, CustomStringConvertible {
        /// The file is not a DXF, DWG or JWW.
        case unrecognizedFormat(fileName: String)

        public var description: String {
            switch self {
            case .unrecognizedFormat(let name):
                return "\(name) is not a DXF, DWG or JWW file"
            }
        }
    }

    /// Read a DXF, DWG or JWW file into one drawing model.
    ///
    /// The format comes from the file's bytes, not its extension.
    public static func read(from url: URL, options: Options = .init()) throws -> DrawingResult {
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        guard let format = DrawingFormat.sniff(data, fileExtension: url.pathExtension) else {
            throw LoadError.unrecognizedFormat(fileName: fileName)
        }
        let readOptions = DXF.ReadOptions(
            expandBlocks: options.expandBlocks, skipPaperSpace: options.skipPaperSpace)

        let drawing: DXF.Drawing
        var source = DrawingSource(
            fileName: fileName, sha256: FileDigest.sha256Hex(data), format: format, version: "")
        var warnings: [DrawingWarning] = []

        switch format {
        case .dxf:
            drawing = try DXF.read(data: data, options: readOptions)
            source.version = drawing.version
        case .dwg:
            let conversion = try DWGLoader.readEntities(
                from: url, converter: options.converter, options: readOptions)
            drawing = conversion.drawing
            source.version = conversion.sourceVersion
            source.converter = conversion.converter
            warnings += conversion.warnings.map {
                DrawingWarning(kind: .converter, message: $0)
            }
        case .jww:
            let jww = try JWW.read(data: data)
            drawing = try DXF.read(text: DXFWriter.string(jww), options: readOptions)
            source.version = String(jww.version)
        }

        warnings += self.warnings(for: drawing, expandedBlocks: options.expandBlocks)
        return DrawingResult(drawing: drawing, source: source, warnings: warnings)
    }

    /// The warnings a drawing carries: what was skipped, assumed, or reported by the reader.
    static func warnings(for drawing: DXF.Drawing, expandedBlocks: Bool) -> [DrawingWarning] {
        var out: [DrawingWarning] = []
        for type in drawing.skippedByLayer.keys.sorted() {
            for (layer, count) in (drawing.skippedByLayer[type] ?? [:]).sorted(by: {
                $0.key < $1.key
            }) {
                out.append(
                    DrawingWarning(
                        kind: .skippedEntities, type: type, layer: layer, count: count,
                        message: "\(count) \(type) entities on layer \(layer) were not read"))
            }
        }
        for (type, count) in drawing.paperSpace.sorted(by: { $0.key < $1.key }) {
            out.append(
                DrawingWarning(
                    kind: .paperSpaceEntities, type: type, count: count,
                    message: "\(count) \(type) entities are in paper space"))
        }
        for warning in drawing.warnings {
            switch warning {
            case .missingBlock(let name, let count):
                out.append(
                    DrawingWarning(
                        kind: .missingBlock, type: name, count: count, message: warning.description)
                )
            case .blockCycle(let name):
                out.append(
                    DrawingWarning(kind: .blockCycle, type: name, message: warning.description))
            case .blockNestingTooDeep(let name):
                out.append(
                    DrawingWarning(
                        kind: .blockNestingTooDeep, type: name, message: warning.description))
            case .notTransformed(let type, let count):
                out.append(
                    DrawingWarning(
                        kind: .notTransformed, type: type, count: count,
                        message: warning.description))
            case .unsupportedExtrusion(let count):
                out.append(
                    DrawingWarning(
                        kind: .unsupportedExtrusion, count: count, message: warning.description))
            case .extrusionNotApplied(let type, let count):
                out.append(
                    DrawingWarning(
                        kind: .extrusionNotApplied, type: type, count: count,
                        message: warning.description))
            case .expansionTruncated:
                out.append(
                    DrawingWarning(kind: .expansionTruncated, message: warning.description))
            }
        }
        if drawing.insUnits == nil || drawing.insUnits == 0 {
            out.append(
                DrawingWarning(
                    kind: .unitsNotDeclared, message: "the file declares no length unit"))
        }
        if drawing.entities.isEmpty {
            out.append(
                DrawingWarning(kind: .emptyDrawing, message: "the drawing has no entities"))
        }
        return out
    }
}

/// SHA-256 of file bytes.
enum FileDigest {
    static func sha256Hex(_ data: Data) -> String {
        #if canImport(CryptoKit)
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #else
            return ""
        #endif
    }
}

/// `JWW.looksLikeJWW`, behind a name this module owns.
enum JWWSniffer {
    static func looksLikeJWW(_ data: Data) -> Bool { JWW.looksLikeJWW(data) }
}

/// `DXF.looksLikeDXF`, behind a name this module owns.
enum DXFSniffer {
    static func looksLikeDXF(_ data: Data) -> Bool { DXF.looksLikeDXF(data) }
}
