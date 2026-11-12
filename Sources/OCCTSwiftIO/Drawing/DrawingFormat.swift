// DrawingFormat.swift
// OCCTSwiftIO
//
// The 2D drawing formats `DrawingLoader` reads, told apart by what the file starts with.

import Foundation

/// A 2D drawing file format.
public enum DrawingFormat: String, Sendable, Equatable, CaseIterable {
    /// AutoCAD Drawing Interchange Format, ASCII.
    case dxf
    /// AutoCAD native drawing, read through the `dwg2dxf` converter.
    case dwg
    /// Jw_cad.
    case jww

    /// The format of a file, from its first bytes; `fileExtension` is consulted only when the
    /// bytes say nothing, so a DXF named `.dwg` is still read as a DXF.
    public static func sniff(_ data: Data, fileExtension: String? = nil) -> DrawingFormat? {
        if JWWSniffer.looksLikeJWW(data) { return .jww }
        let head = [UInt8](data.prefix(6))
        if head.count == 6, head[0] == 0x41, head[1] == 0x43,
            head[2...].allSatisfy({ $0 >= 0x30 && $0 <= 0x39 })
        {
            return .dwg  // "AC" and four digits: AC1009 through AC1032
        }
        if DXFSniffer.looksLikeDXF(data) { return .dxf }
        switch fileExtension?.lowercased() {
        case "dxf": return .dxf
        case "dwg": return .dwg
        case "jww": return .jww
        default: return nil
        }
    }
}
