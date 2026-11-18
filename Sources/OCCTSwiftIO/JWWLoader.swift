// JWWLoader.swift
// OCCTSwiftIO
//
// Loads JWW (Jw_cad), a 2D vector drawing, into OCCT geometry. JWW is not a B-Rep solid or a mesh;
// it's lines, arcs/circles, points and text in a plane. The file is read as `DrawingLoader` reads it
// (at full size, through SwiftJWW's DXF writer, with block references expanded) and turned into one
// compound of edges by the step DXF and DWG share, so the three formats cannot drift apart.

import Foundation

enum JWWLoader {

    static func load(from url: URL) throws -> ShapeLoadResult {
        let read = try DrawingLoader.readJWW(
            Data(contentsOf: url), options: DXFLoader.shapeReadOptions)
        var result = DXFLoader.shapes(of: read.drawing, layersKnown: true)
        result.warnings += read.warnings
        return result
    }
}
