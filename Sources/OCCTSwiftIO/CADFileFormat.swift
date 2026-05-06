// CADFileFormat.swift
// OCCTSwiftIO
//
// File format enum for ShapeLoader. Used by both load() and downstream
// bridge consumers (OCCTSwiftTools) to pick a code path per format.

import Foundation

/// Supported CAD file formats for loading.
public enum CADFileFormat: String, Sendable {
    case step
    case stl
    case obj
    case brep
    case iges

    public init?(fileExtension ext: String) {
        switch ext.lowercased() {
        case "step", "stp":
            self = .step
        case "stl":
            self = .stl
        case "obj":
            self = .obj
        case "brep", "brp":
            self = .brep
        case "iges", "igs":
            self = .iges
        default:
            return nil
        }
    }
}
