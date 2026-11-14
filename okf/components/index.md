---
type: component
title: Components index
resource: https://github.com/SecondMouseAU/OCCTSwiftIO
tags: [index]
description: Public modules / API surfaces exposed by OCCTSwiftIO.
timestamp: 2026-11-14
---

# Components

Public product/target from `Package.swift`, plus the key API surfaces from the README.

- **`OCCTSwiftIO`** (library product / target): the single public module. Headless, no Viewport.
  - `ShapeLoader.load(from:format:)`: async loader returning shapes, per-shape colors, and AP242
    dimensions/datums. Supported input formats: STEP, IGES, STL, OBJ, BREP.
  - `ExportManager.export(shapes:format:to:)`: async exporter. Supported output formats: glTF,
    GLB, OBJ, PLY, STEP, BREP.
  - `DrawingLoader.read(from:options:)`: one call and one `DrawingResult` for DXF, DWG and JWW:
    the SwiftDXF `DXF.Drawing`, a `DrawingSource` (file name, SHA-256, format, version) and
    `DrawingWarning`s (skipped entities by type and layer, entities and records a DWG could not
    read, paper space, missing blocks, undeclared units). The format is sniffed from the bytes
    (`DrawingFormat.sniff`). DWG is read by SwiftDWG, JWW by SwiftJWW and passed through its DXF
    writer. Block references are expanded by default. Needs SwiftDXF 0.4.0 or later.
  - `DXFLoader.loadContours(from:options:)`: planar faces with holes from a DXF drawing, as a
    `DXFContourResult` (faces, wires, SwiftDXF warnings and open chains). Needs SwiftDXF 0.3.0 or
    later, which owns chaining, nesting, units and curve fitting; this repo only builds OCCT
    geometry from its segments. `DXFLoader.load(from:)` is the older compound-of-edges path.
  - `DWGLoader.readEntities(from:options:)`: DWG into the SwiftDXF entity model, read in process by
    [SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG) (MIT; a Swift port of ACadSharp's DWG
    reader with the ODA specification). Each read records the source hash and DWG version. No tool
    to install, any platform. Reads R2000 to R2018 (R14 for simple entities); throws `DWG.Error`.
    `import OCCTSwiftIO` re-exports SwiftDWG's `DWG` namespace, as it does SwiftDXF's `DXF`.
    `CADFileFormat` has no `.dwg` case: DWG is an entity-level read, not a `ShapeLoader` format.
  - `DirectoryWatcher`: kqueue-backed file/directory create/modify notifications, macOS-only
    (`#if os(macOS)`). Ignores dotfile writes; starts cleanly on a not-yet-existing path.

> For body-producing loaders (CPU mesh + interleaved vertex buffer + face/edge/vertex pick data),
> downstream consumers use [OCCTSwiftTools](https://github.com/SecondMouseAU/OCCTSwiftTools), which
> wraps this package with the bridge layer.
