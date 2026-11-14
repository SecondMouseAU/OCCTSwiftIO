// DrawingSource.swift
// OCCTSwiftIO
//
// Where a drawing came from, in the same form for every format.

import Foundation

/// The record of one drawing read: the file, its bytes, its format and its version.
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

    public init(fileName: String, sha256: String, format: DrawingFormat, version: String) {
        self.fileName = fileName
        self.sha256 = sha256
        self.format = format
        self.version = version
    }
}
