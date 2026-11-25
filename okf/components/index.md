---
type: component
title: Components index
resource: https://github.com/SecondMouseAU/OCCTSwiftIO
tags: [index]
description: Public modules / API surfaces exposed by OCCTSwiftIO.
timestamp: 2026-11-21
---

# Components

Public products/targets from `Package.swift` (there are two), plus the key API surfaces from the README.

- **`MeshIO`** (library product / target): pure Swift, no OCCT. `MeshIO.load(contentsOf:weldEpsilon:)`
  reads STL, OBJ, PLY, glTF, GLB, 3MF, PMX and DirectX `.x` into a neutral `Mesh`;
  `MeshIO.write(_:to:format:asciiSTL:)` writes all but PMX and `.x`. The two products do not depend
  on each other. Everything each one reads and writes is in
  [Formats](https://github.com/SecondMouseAU/OCCTSwiftIO/blob/main/docs/formats.md).
- **`OCCTSwiftIO`** (library product / target): the OCCT-backed product. Headless, no Viewport.
  - `ShapeLoader.load(from:format:)`: async loader returning shapes, per-shape colors, and AP242
    dimensions/datums. Supported input formats (`CADFileFormat`): STEP, IGES, STL, OBJ, BREP, and
    the 2D vector formats DXF, DWG and JWW, which load as one compound of edges with block
    references expanded and what was left out in `warnings`. A STEP assembly loads as one entry per
    leaf, not as its root compound too. `ShapeLoader.loadFromManifest(at:)` reads a `ScriptManifest`.
  - `ExportManager.export(shapes:format:to:)`: async exporter. Supported output formats: glTF,
    GLB, OBJ, PLY, STEP, BREP.
  - `DrawingLoader.read(from:options:)`: one call and one `DrawingResult` for DXF, DWG and JWW:
    the SwiftDXF `DXF.Drawing`, a `DrawingSource` (file name, SHA-256, format, version) and
    `DrawingWarning`s (skipped entities by type and layer, entities and records a DWG could not
    read, paper space, missing blocks, undeclared units). The format is sniffed from the bytes
    (`DrawingFormat.sniff`). DWG is read by SwiftDWG, JWW by SwiftJWW and passed through its DXF
    writer at full size, with the dimensions it rebuilds from loose pieces listed in
    `rebuiltDimensions`, each with the pieces it was built from (#77), the values it cannot
    explain in `unexplainedDimensionValues`, and each layer group's scale in `layerGroupScales`
    (#67). Block references are expanded by default.
    Needs SwiftDXF 0.6.x (0.7.0 and later are not supported until adopted, #91), SwiftJWW 1.5.0 or later and SwiftDWG 0.2.0 or later.
  - `DXFLoader.loadContours(from:options:)`: planar faces with holes from a DXF drawing, as a
    `DXFContourResult` (faces, wires, SwiftDXF warnings and open chains). Needs SwiftDXF 0.3.0 or
    later, which owns chaining, nesting, units and curve fitting; this repo only builds OCCT
    geometry from its segments. `DXFLoader.load(from:)` is the older compound-of-edges path.
  - `DWGLoader.readEntities(from:options:)`: DWG into the SwiftDXF entity model, read in process by
    [SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG) (MIT; a Swift port of ACadSharp's DWG
    reader with the ODA specification). Each read records the source hash and DWG version. No tool
    to install, any platform. Versions read, what throws `DWG.Error`, and SwiftDWG's limits are in
    [the DWGLoader reference](https://github.com/SecondMouseAU/OCCTSwiftIO/blob/main/docs/reference/DWGLoader.md).
    `import OCCTSwiftIO` re-exports SwiftDWG's `DWG` namespace, as it does SwiftDXF's `DXF`.
    `ShapeLoader` also loads a DWG (`CADFileFormat.dwg`) as one compound of edges, as it does a DXF.
    Block references are expanded on both, and `ShapeLoadResult.warnings` carries the same
    `DrawingWarning`s `DrawingLoader` gives, and a `.noEdges` warning for each type and layer of
    entity it read and made no edge of (text, dimensions, hatches, leaders, tolerance frames, solid
    fills, wipeouts, 3D faces); use `DrawingLoader` for the entities.
  - `DirectoryWatcher`: kqueue-backed file/directory create/modify notifications, macOS-only
    (`#if os(macOS)`). Ignores dotfile writes; starts cleanly on a not-yet-existing path.

> For body-producing loaders (CPU mesh + interleaved vertex buffer + face/edge/vertex pick data),
> downstream consumers use [OCCTSwiftTools](https://github.com/SecondMouseAU/OCCTSwiftTools), which
> wraps this package with the bridge layer.
