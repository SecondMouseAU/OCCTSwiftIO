// DrawingSource.swift
// OCCTSwiftIO
//
// Where a drawing came from, in the same form for every format.

import Foundation

/// The record of one drawing read: the file, its bytes, its format, and any converter involved.
public struct DrawingSource: Sendable, Equatable {
    /// The file's name, without its directory.
    public var fileName: String
    /// SHA-256 of the file's bytes, lowercase hex.
    ///
    /// Empty where CryptoKit is unavailable.
    public var sha256: String
    public var format: DrawingFormat
    /// The format's own version: `$ACADVER` for DXF (`AC1009`), the version code for DWG
    /// (`AC1032`), the file version for JWW (`700`).
    public var version: String
    /// The converter's version line, such as `dwg2dxf 0.1.0 acadrust 0.6.8`, when a converter
    /// turned the file into the one that was parsed; `nil` otherwise.
    public var converter: String?

    public init(
        fileName: String, sha256: String, format: DrawingFormat, version: String,
        converter: String? = nil
    ) {
        self.fileName = fileName
        self.sha256 = sha256
        self.format = format
        self.version = version
        self.converter = converter
    }
}
