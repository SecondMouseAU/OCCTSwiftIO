---
title: Home
nav_order: 1
---

# OCCTSwiftIO

Headless, multi-format CAD + mesh file I/O for the [OCCTSwift](https://github.com/SecondMouseAU/OCCTSwift)
family — **no Viewport dependency**, so it is safe for CLIs, batch pipelines, and server-side workflows.

The package ships **two products** so consumers take only what they need:

- **`MeshIO`** — pure Swift, **no OCCT**. 3D mesh formats (STL / OBJ / PLY / glTF / GLB / 3MF / PMX / `.x`)
  load and write into a neutral value-type `Mesh` (positions + indices).
- **`OCCTSwiftIO`** — OCCT-backed. CAD B-Rep load/export as `Shape`s (STEP / IGES / BREP), plus **JWW**
  (Jw_cad 2D vector) load, a `ScriptManifest` round-trip, and a `TopologyGraph` → ML export layer.

The split lets OCCT-free consumers (e.g. a raw-mesh ingest) read meshes without pulling in the 1.3 GB
kernel; `OCCTSwiftIO` builds on `MeshIO` and adds the kernel-backed formats. See
[Formats](formats.md) for the full coverage table and per-format notes.

---

## Hero example

```swift
import OCCTSwift
import OCCTSwiftIO

// Load a STEP assembly → shapes + per-shape colors + AP242 GD&T metadata.
let result = try await ShapeLoader.load(from: stepURL, format: .step)
print(result.shapes.count, "shapes,", result.dimensions.count, "dimensions")

// Re-export the loaded shapes as a single binary glTF container.
try await ExportManager.export(shapes: result.shapes, format: .glb, to: outURL)
```

Pure-mesh, no kernel:

```swift
import MeshIO

let mesh = try MeshIO.load(contentsOf: stlURL)     // format chosen by extension
print(mesh.vertexCount, mesh.triangleCount)
try MeshIO.write(mesh, to: objURL)                 // writer chosen by extension
```

---

## Cookbook

Task-oriented, example-rich recipes:

- [Importing a CAD file](guides/cookbook/importing-cad.md) — `ShapeLoader`, format auto-detection, robust loading.
- [Exporting shapes](guides/cookbook/exporting-shapes.md) — `ExportManager` to STEP / BREP / OBJ / PLY / glTF / GLB.
- [Reading & writing meshes](guides/cookbook/mesh-roundtrip.md) — `MeshIO` across STL / OBJ / PLY / glTF / 3MF.
- [The ScriptManifest format](guides/cookbook/script-manifest.md) — load a manifest + sibling BREP bodies.
- [Progress reporting](guides/cookbook/progress-reporting.md) — `ImportProgressClosure` and cancellation.
- [ML graph export](guides/cookbook/ml-export.md) — `TopologyGraph.exportForML()` / `exportJSON()`.

---

## Reference

Per-type API reference with real signatures: [API Reference](reference/README.md).

---

## Install

Add the package and pick the product(s) you need. Latest release: **v1.4.1**.

```swift
dependencies: [
    .package(url: "https://github.com/SecondMouseAU/OCCTSwiftIO.git", from: "1.4.0"),
],
.target(name: "YourTarget", dependencies: [
    .product(name: "MeshIO", package: "OCCTSwiftIO"),        // mesh, no OCCT
    .product(name: "OCCTSwiftIO", package: "OCCTSwiftIO"),   // CAD + JWW + ML (pulls OCCT)
]),
```

GitHub: <https://github.com/SecondMouseAU/OCCTSwiftIO>

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
