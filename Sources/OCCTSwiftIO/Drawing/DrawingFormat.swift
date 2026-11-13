// DrawingFormat.swift
// OCCTSwiftIO
//
// The 2D drawing formats `DrawingLoader` reads, told apart by what the file starts with.

import Foundation
import SwiftDWG

/// A 2D drawing file format.
public enum DrawingFormat: String, Sendable, Equatable, CaseIterable {
    /// AutoCAD Drawing Interchange Format, ASCII.
    case dxf
    /// AutoCAD native drawing, read by SwiftDWG.
    case dwg
    /// Jw_cad.
    case jww

    /// The format of a file, from its first bytes; `fileExtension` is consulted only when the
    /// bytes say nothing, so a DXF named `.dwg` is still read as a DXF.
    public static func sniff(_ data: Data, fileExtension: String? = nil) -> DrawingFormat? {
        if JWWSniffer.looksLikeJWW(data) { return .jww }
        if DWG.looksLikeDWG(data) { return .dwg }  // "AC" and four digits, whatever the release
        if DXFSniffer.looksLikeDXF(data) { return .dxf }
        switch fileExtension?.lowercased() {
        case "dxf": return .dxf
        case "dwg": return .dwg
        case "jww": return .jww
        default: return nil
        }
    }
}
