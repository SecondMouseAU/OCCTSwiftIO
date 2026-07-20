---
title: Cookbook
nav_order: 2
has_children: true
---

# OCCTSwiftIO Cookbook

Task-oriented, **example-rich** guides for the OCCTSwiftIO + MeshIO API — one page per task, each a
short bit of prose followed by runnable Swift snippets using the real shipped API.

## Conventions

- **Every example is runnable Swift** in a fenced `swift` block, using the real current API. Fallible
  loaders / exporters are `throws`; the CAD loaders are `async throws`. Mesh I/O is synchronous.
- **Two imports, two charters.** `import MeshIO` for the pure-Swift mesh path (no OCCT); `import OCCTSwift`
  + `import OCCTSwiftIO` for CAD B-Rep, JWW, manifests, and ML export.
- **Format by extension.** Both `CADFileFormat(fileExtension:)` and `MeshFormat(fileExtension:)` map a
  file extension to a format case; `MeshIO.load` / `MeshIO.write` do this for you.

## Pages

- [Importing a CAD file](importing-cad.md) — `ShapeLoader.load` / `loadRobust`, `CADFileFormat`, colors + AP242 metadata.
- [Exporting shapes](exporting-shapes.md) — `ExportManager.export` to STEP / BREP / OBJ / PLY / glTF / GLB.
- [Reading & writing meshes](mesh-roundtrip.md) — `MeshIO.load` / `write`, the `Mesh` value type, the per-format readers.
- [The ScriptManifest format](script-manifest.md) — `ShapeLoader.loadFromManifest`, `ScriptManifest` / `BodyDescriptor`.
- [Progress reporting](progress-reporting.md) — `ImportProgressClosure`, fraction + step callbacks, cancellation.
- [ML graph export](ml-export.md) — `BRepGraph.exportForML()` / `exportJSON()`, the COO adjacency layout.
