// ShapeLoader.swift
// OCCTSwiftIO
//
// Headless CAD file loader. Returns shapes + colors + AP242 metadata —
// no `ViewportBody`, no Viewport dep. The bridge layer (OCCTSwiftTools)
// wraps this with `ViewportBody` production for renderable consumers.

import Foundation
import simd
import OCCTSwift

/// Result of loading a CAD file via `ShapeLoader`. Pure shape + document data.
///
/// Renderable bodies live in `OCCTSwiftTools.CADLoadResult` — this type is
/// what headless consumers (CLIs, batch tools, server-side pipelines) use
/// when they don't need a Metal-renderable representation.
public struct ShapeLoadResult: @unchecked Sendable {
    /// Source shapes paired with their per-shape color (nil when the format
    /// carries no color information, e.g. STL / OBJ / BREP / IGES).
    public var shapesWithColors: [(shape: Shape, color: SIMD4<Float>?)]

    /// AP242 GD&T dimensions extracted from the document. Empty for non-STEP
    /// formats and for STEP files without GD&T annotations.
    public var dimensions: [DimensionInfo]

    /// AP242 geometric tolerances. Empty for non-STEP formats.
    public var geomTolerances: [GeomToleranceInfo]

    /// AP242 datum references. Empty for non-STEP formats.
    public var datums: [DatumInfo]

    /// The decoded manifest, when this result came from `loadFromManifest`.
    public var manifest: ScriptManifest?

    public init(
        shapesWithColors: [(shape: Shape, color: SIMD4<Float>?)] = [],
        dimensions: [DimensionInfo] = [],
        geomTolerances: [GeomToleranceInfo] = [],
        datums: [DatumInfo] = [],
        manifest: ScriptManifest? = nil
    ) {
        self.shapesWithColors = shapesWithColors
        self.dimensions = dimensions
        self.geomTolerances = geomTolerances
        self.datums = datums
        self.manifest = manifest
    }

    /// Convenience: just the shapes, dropping color info.
    public var shapes: [Shape] { shapesWithColors.map(\.shape) }
}

/// Loads CAD files via OCCTSwift, returning shapes + document metadata.
public enum ShapeLoader {

    /// Loads a CAD file. STEP and IGES honor the `progress` observer; STL /
    /// OBJ / BREP loaders are single-call upstream and don't surface progress.
    /// If `progress.shouldCancel()` returns `true`, throws `ImportError.cancelled`.
    public static func load(
        from url: URL,
        format: CADFileFormat,
        progress: ImportProgress? = nil
    ) async throws -> ShapeLoadResult {
        try await Task.detached {
            try loadSync(from: url, format: format, progress: progress, robust: false)
        }.value
    }

    /// Robust variant — uses the sewing/healing path for STL and IGES (which
    /// commonly ship with gaps OCCT's basic importer can't close). For STEP /
    /// OBJ / BREP this is identical to `load(from:format:progress:)`.
    public static func loadRobust(
        from url: URL,
        format: CADFileFormat,
        progress: ImportProgress? = nil
    ) async throws -> ShapeLoadResult {
        try await Task.detached {
            try loadSync(from: url, format: format, progress: progress, robust: true)
        }.value
    }

    /// Loads bodies from a script manifest (manifest.json + sibling BREP files).
    /// Resolves each `BodyDescriptor.file` relative to the manifest's directory.
    /// Skips entries whose file is missing.
    public static func loadFromManifest(at url: URL) throws -> ShapeLoadResult {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ScriptManifest.self, from: data)
        let baseDir = url.deletingLastPathComponent()

        var shapesWithColors: [(shape: Shape, color: SIMD4<Float>?)] = []
        for descriptor in manifest.bodies {
            let fileURL = baseDir.appendingPathComponent(descriptor.file)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            let shape = try Shape.loadBREP(from: fileURL)
            shapesWithColors.append((shape: shape, color: descriptor.color))
        }
        return ShapeLoadResult(shapesWithColors: shapesWithColors, manifest: manifest)
    }

    // MARK: - Sync per-format dispatch

    private static func loadSync(
        from url: URL,
        format: CADFileFormat,
        progress: ImportProgress?,
        robust: Bool
    ) throws -> ShapeLoadResult {
        switch format {
        case .step:
            return try loadSTEP(from: url, progress: progress)
        case .stl:
            return try loadSTL(from: url, robust: robust)
        case .obj:
            return try loadOBJ(from: url)
        case .brep:
            return try loadBREP(from: url)
        case .iges:
            return try loadIGES(from: url, progress: progress, robust: robust)
        case .jww:
            return try JWWLoader.load(from: url)
        case .dxf:
            return try DXFLoader.load(from: url)
        }
    }

    private static func loadSTEP(from url: URL, progress: ImportProgress?) throws -> ShapeLoadResult {
        let doc = try Document.load(from: url, progress: progress)
        let pairs = doc.shapesWithColors()
        let shapesWithColors: [(shape: Shape, color: SIMD4<Float>?)] = pairs.map { pair in
            let rgba: SIMD4<Float>?
            if let c = pair.color {
                rgba = SIMD4<Float>(Float(c.red), Float(c.green), Float(c.blue), Float(c.alpha))
            } else {
                rgba = nil
            }
            return (shape: pair.shape, color: rgba)
        }
        return ShapeLoadResult(
            shapesWithColors: shapesWithColors,
            dimensions: doc.dimensions,
            geomTolerances: doc.geomTolerances,
            datums: doc.datums
        )
    }

    private static func loadSTL(from url: URL, robust: Bool) throws -> ShapeLoadResult {
        let shape = try (robust ? Shape.loadSTLRobust(from: url) : Shape.loadSTL(from: url))
        return ShapeLoadResult(shapesWithColors: bodyEntries(from: shape))
    }

    private static func loadOBJ(from url: URL) throws -> ShapeLoadResult {
        let shape = try Shape.loadOBJ(from: url)
        return ShapeLoadResult(shapesWithColors: bodyEntries(from: shape))
    }

    private static func loadBREP(from url: URL) throws -> ShapeLoadResult {
        let shape = try Shape.loadBREP(from: url)
        return ShapeLoadResult(shapesWithColors: bodyEntries(from: shape))
    }

    private static func loadIGES(from url: URL, progress: ImportProgress?, robust: Bool) throws -> ShapeLoadResult {
        let shape = try (robust
            ? Shape.loadIGESRobust(from: url, progress: progress)
            : Shape.loadIGES(from: url, progress: progress))
        return ShapeLoadResult(shapesWithColors: bodyEntries(from: shape))
    }

    /// One `shapesWithColors` entry per body, so the colorless formats match the
    /// per-body granularity the STEP path already gives via `Document.shapesWithColors()`.
    ///
    /// Since OCCTSwift v1.11.3 the robust importers return a `Compound` of solids
    /// for a multibody file (before then they silently dropped all but the first —
    /// SecondMouseAU/OCCTSwift#302). A plain `Solid`, or a compound that carries no
    /// solids (e.g. a raw-mesh STL that came back as loose faces), stays a single
    /// entry — the caller still gets the whole shape, just not split. These formats
    /// carry no color, so every entry is `nil`.
    private static func bodyEntries(from shape: Shape) -> [(shape: Shape, color: SIMD4<Float>?)] {
        let bodies = shape.shapeType == .solid ? [shape] : shape.subShapes(ofType: .solid)
        return (bodies.isEmpty ? [shape] : bodies).map { (shape: $0, color: nil) }
    }
}
