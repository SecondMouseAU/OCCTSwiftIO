---
type: component
title: Components index
resource: https://github.com/SecondMouseAU/OCCTSwiftIO
tags: [index]
description: Public modules / API surfaces exposed by OCCTSwiftIO.
timestamp: 2026-06-22
---

# Components

Public product/target from `Package.swift`, plus the key API surfaces from the README.

- **`OCCTSwiftIO`** (library product / target): the single public module. Headless, no Viewport.
  - `ShapeLoader.load(from:format:)`: async loader returning shapes, per-shape colors, and AP242
    dimensions/datums. Supported input formats: STEP, IGES, STL, OBJ, BREP.
  - `ExportManager.export(shapes:format:to:)`: async exporter. Supported output formats: glTF,
    GLB, OBJ, PLY, STEP, BREP.
  - `DXFLoader.loadContours(from:options:)`: planar faces with holes from a DXF drawing, as a
    `DXFContourResult` (faces, wires, SwiftDXF warnings and open chains). Needs SwiftDXF 0.3.0 or
    later, which owns chaining, nesting, units and curve fitting; this repo only builds OCCT
    geometry from its segments. `DXFLoader.load(from:)` is the older compound-of-edges path.
  - `DWGLoader.readEntities(from:converter:)`: DWG into the SwiftDXF entity model, by running the
    `dwg2dxf` tool in `Tools/dwg2dxf` (Rust, on acadrust, MPL-2.0) and parsing its DXF output. Each
    read records the source hash, DWG version and converter version. macOS-only; needs the tool
    built and on `PATH` or named by `OCCTSWIFTIO_DWG2DXF`.
  - `DirectoryWatcher`: kqueue-backed file/directory create/modify notifications, macOS-only
    (`#if os(macOS)`). Ignores dotfile writes; starts cleanly on a not-yet-existing path.

> For body-producing loaders (CPU mesh + interleaved vertex buffer + face/edge/vertex pick data),
> downstream consumers use [OCCTSwiftTools](https://github.com/SecondMouseAU/OCCTSwiftTools), which
> wraps this package with the bridge layer.
