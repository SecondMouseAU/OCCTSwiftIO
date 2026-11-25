# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo state

`v0.1.0` is the spin-out of file-I/O concerns from [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) per [OCCTSwiftTools#12](https://github.com/gsdali/OCCTSwiftTools/issues/12). The point: headless consumers (Scripts, PadCAM CLI, batch pipelines) shouldn't drag in `OCCTSwiftViewport` transitively just to load a STEP file.

Load-bearing types in `Sources/OCCTSwiftIO/`:

- `DrawingLoader`: DXF / DWG / JWW → one `DrawingResult` (SwiftDXF `DXF.Drawing`, `DrawingSource`, `DrawingWarning`s, and for a JWW its rebuilt dimensions with the pieces each was built from, unexplained dimension values and layer group scales). The one entry point for 2D drawing import; format sniffed from the bytes, blocks expanded by default, a JWW at full size.
- `DWGLoader`: DWG → `DXF.Drawing`, read in process by [SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG) (no subprocess, no tool to build). Re-exports SwiftDWG's `DWG` namespace; a bad file throws `DWG.Error`.
- `ShapeLoader`: STEP / IGES / STL / OBJ / BREP / manifest → `ShapeLoadResult` (shapes + colors + AP242 metadata, **no bodies**). DXF, DWG and JWW load as one compound of edges, with blocks expanded and `warnings`.
- `ExportManager`: OBJ / PLY / STEP / BREP / glTF / GLB writers.
- `CADBodyMetadata`: pure-data type (face/edge/vertex pick indices). Produced by `OCCTSwiftTools.CADFileLoader.shapeToBodyAndMetadata` on the bridge side; lives here so the type itself doesn't carry a Viewport dep.
- `ScriptManifest`: Codable manifest format for the script harness.
- `ImportProgressClosure`: closure-backed `OCCTSwift.ImportProgress` for one-shot use.
- `DirectoryWatcher`: kqueue-backed file/directory change notifications, macOS-only
  (`#if os(macOS)`, per the platform floor below). Ported from `OCCTSwiftViewport`'s demo-app
  `ScriptWatcher.swift` into a public, dependency-free type ([#42](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/42)).

## Architectural position

```
OCCTSwiftAIS          (depends on Tools)
       ↑
OCCTSwiftTools        (bridge: Shape ↔ ViewportBody, depends on IO + Viewport)
   ↑       ↑
   |   OCCTSwiftViewport  (Metal renderer)
   |
OCCTSwiftIO           ← this repo
       ↑
OCCTSwift             (B-Rep kernel)
```

**Hard rule: no Viewport dependency in this package.** That's the entire point. If you need to produce a `ViewportBody`, do it in `OCCTSwiftTools` (the bridge layer one floor up).

## Build & test

```bash
swift build
OCCT_SERIAL=1 swift test --parallel --num-workers 1                    # MUST run serially
OCCT_SERIAL=1 swift test --parallel --num-workers 1 \
    --filter ShapeLoaderTests/t_stepRoundTripProducesShapes             # single test
```

`OCCT_SERIAL=1` + serial workers is **required**: known NCollection container-overflow race in OCCT on arm64 macOS. Inherited from OCCTSwift; do not "fix".

`--filter` takes a regex over the test ID; use the Swift type name of the `@Suite` (e.g. `ShapeLoaderTests`), not the suite's display string.

## Behaviors worth knowing

These are non-obvious from type signatures and easy to get wrong:

- **AP242 metadata is STEP-only.** `ShapeLoadResult.dimensions / geomTolerances / datums` are populated only when loading STEP files via `Document.load`. Non-STEP formats (STL / OBJ / BREP / IGES) always return empty arrays; that's not a bug to fix, it's the format limitation.
- **`loadRobust` only differs for STL and IGES.** Those formats often ship with gaps that the basic importer can't close, so the robust path runs sewing/healing. For STEP / OBJ / BREP, `loadRobust` is identical to `load`.
- **Multi-shape export auto-numbers files.** `ExportManager.export(shapes:format:to:)` writes one file per shape when given >1 shape, inserting an index before the extension (`out.glb` → `out.0.glb`, `out.1.glb`, ...). Callers that expected a single combined file will be surprised.
- **A DXF or DWG through `ShapeLoader` is a compound of edges, with its block references expanded and its warnings in `ShapeLoadResult.warnings`.** `CADFileFormat.dwg` reads the DWG as `DXFLoader` reads a DXF: lines, arcs, circles, ellipses, polylines and splines become edges, text, dimensions, hatches, leaders, tolerance frames, solid fills, wipeouts and 3D faces have none, and each is counted in a `.noEdges` warning (the next item). Both are read with `DXF.ReadOptions(expandBlocks: true, expandAttributes: true)` (`DXFLoader.shapeReadOptions`), as `DrawingLoader` reads them but for the attributes, so the geometry in an `INSERT` is in the compound (#70: on four real DWGs 8 to 44 % of the curves were in blocks). `warnings` is `DrawingLoader.warnings(...)` for the same read, and then the `.noEdges` warnings, so the two loaders say the same thing about a file but for that kind; a test pins that. JWW goes through the same step (next item). Other formats leave it empty. A bad file throws `DWG.Error`. Use `DrawingLoader` for the entities.
- **A JWW comes back at full size, with the dimensions SwiftJWW rebuilds (#67).** `DrawingLoader.readJWW` (shared by `DrawingLoader` and `JWWLoader`, so `ShapeLoader` agrees) asks SwiftJWW's `DXFWriter` for `fullSize` and `recoversDimensions`: each element is multiplied by its own layer group's scale, layers are named `<group>-<layer>` in hex (`0-E`), and loose dimension pieces with Jw_cad's flags become `DIMENSION`s. What the DXF text cannot carry comes from the writer's report and the `JWW.Drawing`: `rebuiltDimensions` (matched by handle, which survives SwiftDXF's parse as the identity), each with its `pieces` (#77: the report's `recoveredDimensionElements` for the handle; a line parallel to the `DIMENSION`'s rotation, sine under 0.001 as in SwiftJWW's recovery, is a dimension line and any other an extension line, which a test on the real drawings checks against `recoveringDimensions()`), `unexplainedDimensionValues` (the report's unmatched texts by element index, plus the values of dimension records with no measured points, which a file older than 4.20 has and the writer leaves loose), `layerGroupScales` (the report's `appliedScales`). Every position is multiplied by the report's `appliedScales` for the element's group and every layer is named by `DXFWriter.layerName`, so nothing here copies the writer's scale rule or layer naming; the copies left are `LayerGroupScale.layerNamePrefix`, which a test holds to `DXFWriter.layerName`, and that 0.001 threshold. A group states no usable scale when the factor applied differs from the scale it states. The `SOLID` warning counts fills inside blocks as `unreadable` counts (#81): once per placement when blocks are expanded (`expandingBlocks().solidCount`, run only when a block holds a fill), once per block definition when not (`skippedSolidCount`, and the message says how many are in block definitions). A negative-sweep elliptical arc was written as the rest of the ellipse until SwiftJWW 1.5.0 (SwiftJWW#23).
- **A STEP assembly loads as its leaves.** `ShapeLoader` returns one entry per leaf solid (or part), placed as in the assembly, and not the root compound as well: `Document.shapesWithColors()` returns both, which drew every triangle twice (#41). A compound that is the only thing in the file is the model and is kept.
- **Color is only carried by STEP.** STL / OBJ / BREP / IGES all return `color: nil` per shape; `shapesWithColors` still pairs them, but the color slot is empty.
- **Progress callbacks fire off the main thread.** `ImportProgressClosure` runs on whatever thread the importer used (usually a background thread under the async API). UI updates must hop to `@MainActor` explicitly.
- **The shapes path warns of what it read and made no edge of (#91).** `DXFLoader.shapes(of:layersKnown:)` counts each `TEXT`, `DIMENSION`, `HATCH`, `LEADER`, `TOLERANCE`, `SOLID`, `WIPEOUT` and `3DFACE` by type and layer in a `.noEdges` warning (`NoEdgeTally`, `DXFLoader+NoEdges.swift`), after `DrawingLoader`'s own warnings; `DrawingLoader` never gives that kind, because it returns the entities. A new `DXF.Entity` case does not compile in either switch until it is placed. `shapeReadOptions` sets `expandAttributes` so a block's visible attribute values are counted as `TEXT`; SwiftDXF 0.6 keeps an `ATTDEF` on its block and an `ATTRIB` on its reference otherwise. Tests that compare the two loaders' warnings filter `.noEdges` out.
- **A DWG's warnings differ from a DXF's.** SwiftDWG's skipped entities carry no layer, so `DrawingWarning.layer` is `nil` for a DWG (`layersKnown: false`). An `UNREADABLE_<type>` entry in `skipped` surfaces as a `.unreadable` warning (type without the prefix), never as `.skippedEntities`; the prefix and the five table names are copied from SwiftDWG's README into `DrawingLoader+Skipped.swift`, so check them when SwiftDWG is upgraded. A damaged control object or a release SwiftDWG does not read (R12 and earlier) throws `DWG.Error` from `DWGLoader` and `DrawingLoader`, as does a non-DWG from `DWGLoader` (from `DrawingLoader` only when the file is named `.dwg`, else `LoadError.unrecognizedFormat`); it is not wrapped. SwiftDWG runs in this process; its limits, and what a corrupt file can do, are in `docs/reference/DWGLoader.md` (the one account of them: do not restate them here).
- **`DirectoryWatcher` is macOS-only.** kqueue is a Darwin primitive; the whole file is gated `#if os(macOS)` so the package still builds for iOS/visionOS/tvOS with the type simply absent there.

## Platform floor

`Package.swift` pins `.iOS(.v18)`, `.macOS(.v15)`, `.visionOS(.v1)`, `.tvOS(.v18)`, matching OCCTSwiftTools so consumers using both don't have to reconcile. Could in principle relax to OCCTSwift's (15.0/12.0) since IO has no Viewport dep, but the practical consumer set lives at the Tools floor. One type, `DirectoryWatcher`, is narrower than the package floor: macOS-only, since kqueue has no equivalent wired up here for the other three platforms.

## Conventions cribbed from OCCTSwift

- **License**: LGPL 2.1 (matches OCCT / OCCTSwift / OCCTSwiftTools).
- **Swift**: tools-version 6.1, language mode `.v6`.
- **Tests**: Swift Testing (`@Suite` / `@Test` / `#expect`). Swift Testing **does not short-circuit**: never `#expect(x != nil); #expect(x!.isValid)`. Always `if let x { #expect(x.isValid) }`.
- **Test names must not shadow API method names** used inside the body; runner gets confused. Prefix `t_` or use descriptive English.
- **Versioning (pre-1.0)**: tiny additive features = patch bump. Minor for new public API surface. Free to break; document in `docs/CHANGELOG.md`.
- **Release pattern**: every shipped version commits + pushes + tags + creates a GitHub release with notes from CHANGELOG.

## What is explicitly out of scope

- Anything that produces `ViewportBody`. That's `OCCTSwiftTools`.
- Selection / picking / dimension widgets. That's `OCCTSwiftAIS` (two layers up).
- Headless ray tracing: use CADRays separately.
- Linux / Windows / Android / watchOS.

## Ecosystem context

- `~/Projects/OCCTSwift/CLAUDE.md`: kernel project conventions (this repo follows them).
- `~/Projects/OCCTSwiftTools/CLAUDE.md`: sibling that wraps this package with the bridge layer.
