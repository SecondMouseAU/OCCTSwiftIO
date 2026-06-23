---
title: ShapeLoader
parent: API Reference
---

# ShapeLoader

`ShapeLoader` is a headless CAD file loader. Its static methods load STEP / IGES / BREP / STL / OBJ /
JWW into OCCT `Shape`s plus document metadata, returning a `ShapeLoadResult`. There is no Viewport
dependency — renderable bodies live in OCCTSwiftTools, which wraps this package.

## Topics

- [`ShapeLoadResult`](#shapeloadresult) · [`ShapeLoader.load(from:format:progress:)`](#shapeloaderloadfromformatprogress) · [`ShapeLoader.loadRobust(from:format:progress:)`](#shapeloaderloadrobustfromformatprogress) · [`ShapeLoader.loadFromManifest(at:)`](#shapeloaderloadfrommanifestat)

---

## `ShapeLoadResult`

The value returned by every `ShapeLoader` entry point: pure shape + document data.

```swift
public struct ShapeLoadResult: @unchecked Sendable {
    public var shapesWithColors: [(shape: Shape, color: SIMD4<Float>?)]
    public var dimensions: [DimensionInfo]
    public var geomTolerances: [GeomToleranceInfo]
    public var datums: [DatumInfo]
    public var manifest: ScriptManifest?

    public init(
        shapesWithColors: [(shape: Shape, color: SIMD4<Float>?)] = [],
        dimensions: [DimensionInfo] = [],
        geomTolerances: [GeomToleranceInfo] = [],
        datums: [DatumInfo] = [],
        manifest: ScriptManifest? = nil
    )

    /// Convenience: just the shapes, dropping color info.
    public var shapes: [Shape] { get }
}
```

- `shapesWithColors` — source shapes paired with a per-shape color, `nil` when the format carries no
  color (STL / OBJ / BREP / IGES).
- `dimensions` / `geomTolerances` / `datums` — AP242 GD&T extracted from the document (STEP only;
  empty otherwise). The element types (`DimensionInfo`, `GeomToleranceInfo`, `DatumInfo`) come from
  OCCTSwift.
- `manifest` — the decoded manifest, populated only by `loadFromManifest`.
- `shapes` — convenience accessor returning just the shapes.

---

## `ShapeLoader.load(from:format:progress:)`

Loads a CAD file. STEP and IGES honour the `progress` observer; STL / OBJ / BREP loaders are
single-call upstream and don't surface progress.

```swift
public static func load(
    from url: URL,
    format: CADFileFormat,
    progress: ImportProgress? = nil
) async throws -> ShapeLoadResult
```

- **Parameters:** `url` — the file to load; `format` — the `CADFileFormat` selecting the code path;
  `progress` — optional `ImportProgress` observer (see [ImportProgressClosure](ImportProgressClosure.md)).
- **Returns:** a `ShapeLoadResult` with shapes, colors, and (for STEP) AP242 metadata.
- **Throws:** rethrows OCCTSwift import errors; `ImportError.cancelled` if `progress.shouldCancel()`
  returns `true`.
- **Example:**
  ```swift
  let result = try await ShapeLoader.load(from: stepURL, format: .step)
  for (shape, color) in result.shapesWithColors { print(shape, color as Any) }
  ```

---

## `ShapeLoader.loadRobust(from:format:progress:)`

Robust variant — routes STL and IGES through the sewing/healing path (which closes gaps the basic
importer can't). For STEP / OBJ / BREP this is identical to `load(from:format:progress:)`.

```swift
public static func loadRobust(
    from url: URL,
    format: CADFileFormat,
    progress: ImportProgress? = nil
) async throws -> ShapeLoadResult
```

- **Parameters:** as `load(from:format:progress:)`.
- **Returns:** a `ShapeLoadResult`.
- **Throws:** rethrows OCCTSwift import / healing errors; `ImportError.cancelled` on cancellation.
- **Example:**
  ```swift
  let healed = try await ShapeLoader.loadRobust(from: igesURL, format: .iges)
  ```

---

## `ShapeLoader.loadFromManifest(at:)`

Loads bodies from a script manifest (`manifest.json` + sibling BREP files). Resolves each
`BodyDescriptor.file` relative to the manifest's directory and skips entries whose file is missing.
This entry point is synchronous `throws`, not `async`.

```swift
public static func loadFromManifest(at url: URL) throws -> ShapeLoadResult
```

- **Parameters:** `url` — the URL of the `manifest.json` document.
- **Returns:** a `ShapeLoadResult` whose `manifest` property holds the decoded `ScriptManifest` and
  whose `shapesWithColors` pairs each loaded BREP body with its `BodyDescriptor.color`.
- **Throws:** if the manifest can't be read or decoded, or if a referenced BREP fails to load.
- **Example:**
  ```swift
  let result = try ShapeLoader.loadFromManifest(at: manifestURL)
  print(result.manifest?.bodies.count ?? 0, "bodies")
  ```
