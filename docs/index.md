---
title: Home
nav_order: 1
---

# OCCTSwiftIO

Headless, multi-format CAD + mesh file I/O for the [OCCTSwift](https://github.com/SecondMouseAU/OCCTSwift)
family: **no Viewport dependency**, so it is safe for CLIs, batch pipelines, and server-side workflows.

The package ships **two products**: `MeshIO` (pure Swift, no OCCT) for 3D mesh formats, and
`OCCTSwiftIO` (OCCT-backed) for CAD B-Rep and 2D drawings. The
[README](https://github.com/SecondMouseAU/OCCTSwiftIO#readme) says what each is for and how they
relate; [Formats](formats.md) has everything each one reads and writes.

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

For the pure-mesh path, with no kernel, see [Reading & writing meshes](guides/cookbook/mesh-roundtrip.md).

---

## Cookbook

Task-oriented, example-rich recipes:

- [Importing a CAD file](guides/cookbook/importing-cad.md): `ShapeLoader`, format auto-detection, robust loading.
- [Exporting shapes](guides/cookbook/exporting-shapes.md): `ExportManager` to STEP / BREP / OBJ / PLY / glTF / GLB.
- [Reading & writing meshes](guides/cookbook/mesh-roundtrip.md): `MeshIO` across STL / OBJ / PLY / glTF / 3MF.
- [The ScriptManifest format](guides/cookbook/script-manifest.md): load a manifest + sibling BREP bodies.
- [Progress reporting](guides/cookbook/progress-reporting.md): `ImportProgressClosure` and cancellation.
- [ML graph export](guides/cookbook/ml-export.md): `BRepGraph.exportForML()` / `exportJSON()`.

---

## Reference

Per-type API reference with real signatures: [API Reference](reference/README.md).

---

## Install

The install snippet, and which version to take, are in the
[README](https://github.com/SecondMouseAU/OCCTSwiftIO#install). Releases are on the
[Releases](https://github.com/SecondMouseAU/OCCTSwiftIO/releases) page.

GitHub: <https://github.com/SecondMouseAU/OCCTSwiftIO>

---

## Architecture position

```
OCCTSwiftTools     (bridge: Shape ↔ ViewportBody)
       ↑
OCCTSwiftIO        ← this repo (headless file I/O)        MeshIO  ← pure-Swift mesh (no OCCT)
       ↑                                                     ↑
OCCTSwift          (B-Rep kernel)              SwiftPMX / SwiftX / ThreeMF / SwiftGLTF / SwiftJWW / SwiftDXF / SwiftDWG
```

**Hard rule: no Viewport dependency in this package.** Produce `ViewportBody`s in OCCTSwiftTools.

## License

LGPL-2.1 (inherited from OCCTSwift / OCCT). The mesh-format reader packages carry their own permissive
licenses (MIT / BSD-3).
