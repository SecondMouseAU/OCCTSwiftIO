---
title: Overview
nav_order: 1
---

# OCCTSwiftIO

Headless file I/O for the [OCCTSwift](https://github.com/SecondMouseAU/OCCTSwift) ecosystem — **no
Viewport dependency**, safe for CLIs, batch pipelines, and server-side workflows.

The package ships **two products** so consumers take only what they need:

- **`MeshIO`** — pure Swift, **no OCCT**. 3D mesh formats → a neutral `Mesh` (positions + indices).
- **`OCCTSwiftIO`** — OCCT-backed. CAD B-Rep load/export as `Shape`s, plus **JWW** (Jw_cad 2D vector) load.

The split lets OCCT-free consumers (e.g. a raw-mesh reconstruction ingest) read meshes without pulling
in the 1.3 GB kernel; `OCCTSwiftIO` builds on `MeshIO` and adds the kernel-backed formats. See
[Formats](formats.md) for the full table and per-format notes.

---

## Install

```swift
dependencies: [
    .package(url: "https://github.com/SecondMouseAU/OCCTSwiftIO.git", from: "1.4.0"),
],
.target(name: "YourTarget", dependencies: [
    .product(name: "MeshIO", package: "OCCTSwiftIO"),        // mesh, no OCCT
    .product(name: "OCCTSwiftIO", package: "OCCTSwiftIO"),   // CAD + JWW (pulls OCCT)
]),
```

---

## MeshIO

```swift
import MeshIO

let mesh = try MeshIO.load(contentsOf: url)        // .stl/.obj/.ply/.gltf/.glb/.3mf/.pmx/.x
print(mesh.vertexCount, mesh.triangleCount, mesh.bounds as Any)

try MeshIO.write(mesh, to: outURL)                 // format inferred from extension
try MeshIO.write(mesh, to: stlURL, format: .stl, asciiSTL: true)
```

`Mesh` is a value type:

```swift
public struct Mesh: Equatable, Sendable {
    public var positions: [SIMD3<Float>]
    public var indices: [UInt32]
    public var vertexCount: Int
    public var triangleCount: Int
    public var bounds: (min: SIMD3<Float>, max: SIMD3<Float>)?
}
```

`MeshFormat(fileExtension:)` maps an extension to a format; `MeshFormat.canWrite` reports whether a
writer exists (PMX / `.x` are read-only source formats).

---

## OCCTSwiftIO

```swift
import OCCTSwift
import OCCTSwiftIO

// STEP / IGES / BREP → shapes + colors + AP242 metadata.
let result = try await ShapeLoader.load(from: stepURL, format: .step)
for (shape, color) in result.shapesWithColors { /* … */ }

// JWW (Jw_cad 2D drawing) → one compound Shape of OCCT edges (lines, arcs/circles, points).
let drawing = try await ShapeLoader.load(from: jwwURL, format: .jww)

// Export shapes to STEP / BREP / OBJ / PLY / glTF / GLB.
try await ExportManager.export(shapes: result.shapes, format: .glb, to: outURL)
```

`ShapeLoader.load` returns a `ShapeLoadResult` (shapes + per-shape colors + AP242 dimensions / datums).
For body-producing loaders (CPU mesh + pick data for AIS), use
[OCCTSwiftTools](https://github.com/SecondMouseAU/OCCTSwiftTools), which wraps this package.

---

## Architecture position

```
OCCTSwiftTools     (bridge — Shape ↔ ViewportBody)
       ↑
OCCTSwiftIO        ← this repo (headless file I/O)        MeshIO  ← pure-Swift mesh (no OCCT)
       ↑                                                     ↑
OCCTSwift          (B-Rep kernel)              SwiftPMX / SwiftX / ThreeMF / SwiftGLTF / SwiftJWW
```

**Hard rule: no Viewport dependency in this package.** Produce `ViewportBody`s in OCCTSwiftTools.

## License

LGPL-2.1 (inherited from OCCTSwift / OCCT). The mesh-format reader packages carry their own permissive
licenses (MIT / BSD-3).
