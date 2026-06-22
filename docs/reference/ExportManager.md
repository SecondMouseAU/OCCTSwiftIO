---
title: ExportManager
parent: API Reference
---

# ExportManager

`ExportManager` writes OCCT `Shape`s to mesh, B-Rep, and glTF file formats. It is headless — produces
files from `Shape`, with no Viewport dependency. The companion `ExportFormat` enum lists the targets.

## Topics

- [`ExportFormat`](#exportformat) · [`ExportManager.export(shapes:format:to:deflection:)`](#exportmanagerexportshapesformattodeflection)

---

## `ExportFormat`

The supported export formats. `String`-backed, `CaseIterable`, `Sendable`.

```swift
public enum ExportFormat: String, CaseIterable, Sendable {
    case obj  = "OBJ"
    case ply  = "PLY"
    case step = "STEP"
    case brep = "BREP"
    /// glTF, JSON-encoded with separate `.bin` buffer files (`.gltf`).
    case gltf = "GLTF"
    /// glTF, single binary container (`.glb`). Same data as `.gltf`, smaller on disk.
    case glb  = "GLB"

    public var fileExtension: String { get }
}
```

- `obj` / `ply` / `gltf` / `glb` are meshed exports (use `deflection`); `step` / `brep` write exact
  B-Rep.
- `fileExtension` returns the lowercase extension: `"obj"`, `"ply"`, `"step"`, `"brep"`, `"gltf"`,
  `"glb"`.

---

## `ExportManager.export(shapes:format:to:deflection:)`

Exports shapes to the specified format. When more than one shape is given, writes one file per shape,
inserting the index before the extension (`out.0.step`, `out.1.step`, …); a single-element array
writes the exact `url`. An empty array is a no-op.

```swift
public static func export(
    shapes: [Shape],
    format: ExportFormat,
    to url: URL,
    deflection: Double = 0.1
) async throws
```

- **Parameters:**
  - `shapes` — the OCCT shapes to write.
  - `format` — the target `ExportFormat`.
  - `to url` — destination file URL (the per-shape index is inserted before the extension for
    multi-shape exports).
  - `deflection` — meshing tolerance for the meshed formats (`obj` / `ply` / `gltf` / `glb`); ignored
    by `step` / `brep`. Default `0.1`; smaller is finer.
- **Throws:** rethrows the underlying OCCTSwift `Exporter` errors.
- **Example:**
  ```swift
  let result = try await ShapeLoader.load(from: stepURL, format: .step)
  try await ExportManager.export(shapes: result.shapes, format: .glb, to: outURL, deflection: 0.05)
  ```
