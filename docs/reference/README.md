---
title: API Reference
nav_order: 3
has_children: true
---

# OCCTSwiftIO API Reference

A **per-type function reference** for the public OCCTSwiftIO + MeshIO API — one page per type or
logical group, every public symbol documented with its real signature, parameters, return, and a
runnable example.

The package spans two products:

- **`OCCTSwiftIO`** (OCCT-backed) — CAD load/export, JWW, manifests, ML export.
- **`MeshIO`** (pure Swift, no OCCT) — mesh formats into a neutral `Mesh`.

## Pages

### OCCTSwiftIO (CAD)

- [ShapeLoader](ShapeLoader.md) — `load` / `loadRobust` / `loadFromManifest`, and the `ShapeLoadResult` it returns.
- [ExportManager](ExportManager.md) — `export(shapes:format:to:deflection:)` and the `ExportFormat` enum.
- [CADFileFormat](CADFileFormat.md) — the load-side format enum and its extension initializer.
- [ScriptManifest](ScriptManifest.md) — `ScriptManifest`, `BodyDescriptor`, `ManifestMetadata`.
- [ImportProgressClosure](ImportProgressClosure.md) — closure-backed `ImportProgress` + cancellation.
- [GraphExport (ML)](GraphExport.md) — `TopologyGraph.exportForML()` / `exportJSON()` and the `GraphExport` struct.
- [CADBodyMetadata](CADBodyMetadata.md) — sub-body selection metadata produced by the bridge layer.

### MeshIO (mesh)

- [Mesh](Mesh.md) — the neutral indexed-triangle value type.
- [MeshIO](MeshIO.md) — `load` / `write` plus `MeshFormat` and `MeshError`.
- [Mesh format readers](MeshFormats.md) — `STL`, `OBJ`, `PLY` (native) and the glTF / 3MF adapters.

### Coverage

- [Formats](../formats.md) — the full read/write coverage table and per-format notes.
