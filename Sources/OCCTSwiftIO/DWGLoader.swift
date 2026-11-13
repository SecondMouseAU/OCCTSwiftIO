// DWGLoader.swift
// OCCTSwiftIO
//
// Reads DWG (AutoCAD's native drawing format) into the same SwiftDXF entity model `DXFLoader`
// produces. The reading is SwiftDWG's: a Swift reader that runs in process, so no tool has to be
// built or found and every platform this package supports can read a DWG.
//
// Each read records what was read: the source's SHA-256 and DWG version code, so a drawing can be
// traced back to the bytes it came from.

import Foundation
// Re-export so `import OCCTSwiftIO` brings the `DWG` namespace into scope: `DWGLoader` and
// `DrawingLoader` throw `DWG.Error`, which a caller has to be able to name to catch it.
@_exported import SwiftDWG
import SwiftDXF

public enum DWGLoader {

    /// One DWG read: the drawing, and the record of how it was obtained.
    public struct Conversion: Sendable {
        /// The drawing, in the same entity model `DXFLoader.readEntities` returns.
        public let drawing: DXF.Drawing
        /// SHA-256 of the source file, lowercase hex.
        public let sourceSHA256: String
        /// The source's DWG version code from its first six bytes, such as `AC1032`.
        public let sourceVersion: String
        /// Anything about the result a caller should not miss, one line each: what the reader
        /// could not read, and an empty result.
        public let warnings: [String]
    }

    /// Read a DWG file into the SwiftDXF entity model, with the record of the read.
    ///
    /// - Throws: ``DWG/Error`` when the file is not a DWG, is of a release that is not read, or is
    ///   damaged in its structure. An entity or table record that cannot be read does not throw:
    ///   it is left out and reported in ``Conversion/warnings``.
    public static func readEntities(
        from url: URL, options: DXF.ReadOptions = .init()
    ) throws -> Conversion {
        let source = try Data(contentsOf: url)
        let parsed = try read(data: source, options: options)
        let reported = DrawingLoader.warnings(
            for: parsed.drawing, expandedBlocks: options.expandBlocks, layersKnown: false)
        return Conversion(
            drawing: parsed.drawing, sourceSHA256: FileDigest.sha256Hex(source),
            sourceVersion: parsed.version,
            warnings: reported.filter { $0.kind == .unreadable || $0.kind == .emptyDrawing }
                .map(\.message))
    }

    /// The drawing in a DWG's bytes, and the version code the file starts with.
    static func read(
        data: Data, options: DXF.ReadOptions
    ) throws -> (drawing: DXF.Drawing, version: String) {
        let drawing = try DWG.read(data: data, options: options)
        return (drawing, String(decoding: data.prefix(6), as: UTF8.self))
    }
}
