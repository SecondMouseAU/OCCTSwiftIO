import Foundation
import SwiftPMX
import SwiftX

public enum MeshError: Error, Equatable, Sendable {
    case empty
    case notRecognized
    case unknownExtension(String)
    case unsupported(String)
}

/// The 3D mesh file formats MeshIO handles. Mesh-only — 2D vector formats (JWW/DXF) and CAD B-Rep
/// (STEP/IGES/BREP) live in the OCCT-backed `OCCTSwiftIO` target, not here.
public enum MeshFormat: String, Sendable, CaseIterable {
    case stl, obj, ply, pmx, x          // x = DirectX .x
    case threeMF = "3mf"

    public init?(fileExtension ext: String) {
        switch ext.lowercased() {
        case "stl": self = .stl
        case "obj": self = .obj
        case "ply": self = .ply
        case "pmx": self = .pmx
        case "x":   self = .x
        case "3mf": self = .threeMF
        default: return nil
        }
    }

    public var canRead: Bool { true }
    public var canWrite: Bool { self != .pmx && self != .x }   // pmx/.x are source-only; STL/OBJ/PLY/3MF write
}

/// Pure-Swift mesh file I/O — no OCCT. Reads STL/OBJ/PLY natively and PMX/.x via the standalone
/// SwiftPMX / SwiftX packages, into a neutral ``Mesh``.
public enum MeshIO {

    /// All formats with a reader.
    public static var readableExtensions: [String] { MeshFormat.allCases.map(\.rawValue) }

    /// Load a mesh file, choosing the reader by extension.
    public static func load(contentsOf url: URL, weldEpsilon: Float = 1e-4) throws -> Mesh {
        guard let fmt = MeshFormat(fileExtension: url.pathExtension) else {
            throw MeshError.unknownExtension(url.pathExtension)
        }
        let data = try Data(contentsOf: url)
        switch fmt {
        case .stl: return try STL.read(data: data, weldEpsilon: weldEpsilon)
        case .obj: return try OBJ.read(data: data, weldEpsilon: weldEpsilon)
        case .ply: return try PLY.read(data: data, weldEpsilon: weldEpsilon)
        case .pmx: return adapt(try SwiftPMX.PMX.read(data: data, options: .init(weldEpsilon: weldEpsilon)))
        case .x:   return adapt(try SwiftX.X.read(data: data, options: .init(weldEpsilon: weldEpsilon)))
        case .threeMF: return try readThreeMF(data: data, weldEpsilon: weldEpsilon)
        }
    }

    /// Write a mesh, choosing the writer by `format` (or the file extension if `format` is nil).
    public static func write(_ mesh: Mesh, to url: URL, format: MeshFormat? = nil, asciiSTL: Bool = false) throws {
        let fmt = format ?? MeshFormat(fileExtension: url.pathExtension)
        switch fmt {
        case .stl: try (asciiSTL ? Data(STL.asciiString(mesh).utf8) : STL.binaryData(mesh)).write(to: url)
        case .obj: try Data(OBJ.string(mesh).utf8).write(to: url)
        case .ply: try Data(PLY.string(mesh).utf8).write(to: url)
        case .threeMF: try writeThreeMF(mesh).write(to: url)
        case .pmx, .x, nil: throw MeshError.unsupported("write \(fmt?.rawValue ?? url.pathExtension)")
        }
    }

    // Adapters from the standalone source-format packages' neutral meshes.
    static func adapt(_ m: SwiftPMX.PMX.Mesh) -> Mesh { Mesh(positions: m.positions, indices: m.indices) }
    static func adapt(_ m: SwiftX.X.Mesh) -> Mesh { Mesh(positions: m.positions, indices: m.indices) }
}
