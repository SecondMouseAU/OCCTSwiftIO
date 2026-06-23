---
title: Exporting shapes
parent: Cookbook
nav_order: 2
---

# Exporting shapes

`ExportManager` writes OCCT `Shape`s to mesh, B-Rep, and glTF formats. It is `async throws` and takes
an array of shapes, an `ExportFormat`, and a destination `URL`.

## The six formats

```swift
public enum ExportFormat: String, CaseIterable, Sendable {
    case obj, ply, step, brep, gltf, glb
    public var fileExtension: String { /* "obj", "ply", "step", "brep", "gltf", "glb" */ }
}
```

`obj` / `ply` / `gltf` / `glb` are meshed exports (controlled by `deflection`); `step` / `brep` write
exact B-Rep.

## Export a single shape

```swift
import OCCTSwift
import OCCTSwiftIO

try await ExportManager.export(shapes: [shape], format: .step, to: stepURL)

// glTF/GLB and OBJ/PLY honour the meshing deflection (default 0.1, smaller = finer):
try await ExportManager.export(shapes: [shape], format: .glb, to: glbURL, deflection: 0.05)
```

## Multiple shapes

When you pass more than one shape, `ExportManager` writes **one file per shape**, inserting the index
before the extension (`out.0.step`, `out.1.step`, …). A single-element array writes the exact `url`
you gave:

```swift
let result = try await ShapeLoader.load(from: stepURL, format: .step)
// result.shapes.count files: out.0.obj, out.1.obj, ...
try await ExportManager.export(shapes: result.shapes, format: .obj, to: URL(fileURLWithPath: "out.obj"))
```

An empty `shapes` array is a no-op.

## Mesh-only output without the kernel

If you already have a `Mesh` (or only need a mesh on disk), prefer `MeshIO.write` — it has no OCCT
dependency. `ExportManager` is for exporting B-Rep `Shape`s, including the exact STEP / BREP paths.
