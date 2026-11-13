# Changelog

Most recent first. Pre-1.0: free to break; deprecations documented here. SemVer-stable from v1.0.0.

> Note: v1.1.0–v1.4.1 (MeshIO / 3MF / glTF / JWW) shipped as tagged GitHub releases without entries here; this log resumes at v1.5.0.

## Unreleased

**One entry point for 2D drawing import: `DrawingLoader.read(from:options:)` ([#54](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/54)).** DXF, DWG and JWW come back as one `DrawingResult`: the SwiftDXF `DXF.Drawing`, a `DrawingSource` (file name, SHA-256, format and the format's own version) and `DrawingWarning`s as data (skipped entities by type and layer, entities and records a DWG could not read, paper space, missing or cyclic blocks, entities a non-uniform scale could not carry, undeclared units, an empty drawing). The format is told from the file's bytes (`DrawingFormat.sniff`), with the extension consulted only when the bytes say nothing. JWW is read by SwiftJWW and passed through its DXF writer, so a JWW insert expands like a DXF one. Block references are expanded by default (`Options.expandBlocks`), with the references recorded in each entity's identity. `DXFLoader.readEntities(from:options:)` and `DWGLoader.readEntities(from:options:)` take SwiftDXF's `DXF.ReadOptions`. The hash helper is shared (`FileDigest`).

**DWG tests on files AutoCAD wrote ([#58](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/58) item 3).** `Fixtures/DWG/autocad/` holds small drawings saved by AutoCAD (AC1027 and AC1032), including a DWG with the DXF AutoCAD wrote from the same drawing, taken unmodified from the acadrust repository, where they are published under MPL-2.0 (the licence and the origin are in that folder). They test the reader on files it did not write itself: the line end points, the linear dimension's definition points and rotation, the handles AutoCAD gave (`2C1`, `2C2`, `2C3`) and the names of anonymous blocks, each as the files' author documents them, and the DWG's tables against AutoCAD's own DXF of it. AC1009 to AC1024 still have no independent fixture here (SwiftDWG's own tests cover its releases).

**SwiftDXF moves to `from: "0.4.0"`.** 0.4.0 carries the work behind #55, #56, #57 and #59 (see its README): `DIMENSION` rotation, a computed measurement and `measurement` that is `nil` when group 42 is absent, zero or negative (it was `-1.0` for SolidWorks and McMaster files; use `computedMeasurement` for the value), the dimension style's precision and the text split into parts; `Drawing.identities` (the DXF handle, else the position); block references, the layer and line type tables and per-entity line types; `Entity.fitted(tolerance:)` for splines and ellipses; and the extrusion of arcs, circles and polylines applied. `DXF.Entity` gains `.hatch` and `.leader`, and `DXF.Warning` gains `.extrusionNotApplied` and `.expansionTruncated`, so an exhaustive `switch` over either needs the new cases: `DXFLoader` ignores hatches and leaders (no edges), and `DrawingWarning.Kind` gains `extrusionNotApplied` and `expansionTruncated`. HATCH and LEADER no longer appear in `skipped`. Identities no longer carry a `#` (`31`, `A1/C1`).

**Tests.** The same 100 x 60 plate is read from a DXF (`Fixtures/Drawing/plate.dxf`), the DWG and a JWW generated at test time (`Support/JWWFixture.swift`), and the three have the same lines and circle.

**DWG: Tools/dwg2dxf is gone, SwiftDWG reads it in process ([#58](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/58) item 1).** `DWGLoader.readEntities(from:options:)` returns a `DWGLoader.Conversion`: the drawing in the same SwiftDXF entity model `DXFLoader.readEntities` returns, the source's SHA-256 and DWG version code, and `warnings` (what the reader could not read, an empty result). It reads through [SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG) (`from: "0.1.0"`, MIT, which needs SwiftDXF 0.4.0 or later), a Swift port of ACadSharp's DWG reader with the Open Design Alliance's specification. No subprocess, no Rust toolchain, no tool to find at run time, and not macOS-only. `Tools/dwg2dxf` (the Rust crate on acadrust), `OCCTSWIFTIO_DWG2DXF` and the cargo build and cache steps in `tests.yml` are removed, and the DWG tests, which took a known-issue path without the converter, run unconditionally. `import OCCTSwiftIO` re-exports SwiftDWG's `DWG` namespace, as it does SwiftDXF's `DXF`, because a bad DWG throws `DWG.Error`.

- **Breaking, against main; none of it was in a release.** `DWGLoader.readEntities(from:converter:options:)` loses `converter:`. Removed: `DWGLoader.locateConverter`, `DWGLoader.converterEnvironmentVariable`, `DWGLoader.DWGError` (catch `DWG.Error`: `.notADWG`, `.unsupportedVersion`, `.truncated`, `.invalid`) and `DWGLoader.Conversion.converter`.
- **Not breaking against main: `DrawingLoader.Options.converter`, `DrawingSource.converter` and `DrawingWarning.Kind.converter`.** They exist only in the unmerged DrawingLoader change (#61); this change removes them before they land, because with no converter there is nothing to record in them and a field that is always `nil` would only mislead. `DrawingSource` records the file, its hash, its format and the format's version.
- **The reader now runs in your process.** The subprocess contained whatever went wrong inside the converter. SwiftDWG 0.1.0 throws `DWG.Error` for a truncated file, a file that is not a DWG and a release it does not read, but some bytes changed inside the compressed data of an AC1027 or AC1032 file make it trap (a negative range in its decompression), and some changed in the section map at the end of the file make it run for more than 20 seconds with memory growing. A reader that must survive untrusted DWGs should not run in a process it cannot lose.
- **New: `DrawingWarning.Kind.unreadable`.** SwiftDWG leaves out an entity, table record or block it cannot read and counts it in `skipped` as `UNREADABLE_<type>`. `DrawingLoader` reports each type as `.unreadable` (`type` without the prefix, `OBJECT` when the object has no readable type) and no longer reports it as `.skippedEntities` or as paper space. Blocks that are not expanded (`expandBlocks: false`) are counted too. A file damaged in its structure, such as an unreadable layer, line type, text style, dimension style or block control object, throws `DWG.Error` and is not wrapped.
- **Changed: a DWG's skipped entities have no layer.** SwiftDWG writes the entities it does not model, and the ones it could not read, as bare records, so SwiftDXF counts them on layer `0` (on the layer of the `INSERT`, in a block that was expanded) whatever their layer was. `DrawingWarning.layer` is `nil` for a DWG, and there is one `.skippedEntities` warning per type.
- **Changed: releases read.** SwiftDWG reads R2000 to R2018, and R14 for simple entities. R12 and earlier throw `DWG.Error.unsupportedVersion`; the converter's documentation said AC1009 and later, though no fixture of those releases was ever tested.
- **Unchanged: `CADFileFormat` has no `.dwg` case** and `ShapeLoader` does not load DWG: it is an entity-level read through `DrawingLoader` and `DWGLoader`. Adding the case is source-breaking for an exhaustive `switch` and needs a shapes path for DWG (the DXF one reads a file, not a drawing); it is left to the maintainer ([#58](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/58), "also worth deciding").
- **Tests.** The two AutoCAD-written DWGs and the pair (`point_object_id.dwg` and the DXF AutoCAD wrote from it) from the previous entry now read through SwiftDWG, and the pair agrees on the layer, line type and dimension style tables, handles included. A truncated, damaged or newer-release file throws `DWG.Error` from both loaders, and a non-DWG does from `DWGLoader` (from `DrawingLoader` when the file is named `.dwg`), and what SwiftDWG cannot read comes through as `.unreadable`.

**DXF closed regions as planar faces, on SwiftDXF 0.3.0.** The SwiftDXF dependency moves from `from: "0.2.0"` to `from: "0.3.0"`, which adds `DXF.Entity.spline` (source-breaking for any exhaustive `switch` over `DXF.Entity`; this package's loader is updated) and the OCCT-free contour layer (`drawing.contours`). The OCCTSwift pin is unchanged.

- New `DXFLoader.loadContours(from:options:)` and `DXFLoader.contourFaces(of:options:)` return a `DXFContourResult`: one `DXFContourFace` (face, outer wire, hole wires, analytic area, source contour) per closed region, plus SwiftDXF's `warnings`, `openChains`, `unit`, `unitScale` and `maxFitDeviation` as data, and `shapeLoadResult` for `ShapeLoader` consumers. Chaining, nesting, unit conversion and ellipse/spline fitting stay in SwiftDXF; this package only builds OCCT edges, wires and faces. Arcs are true circular arcs, lines are lines.
- `DXFLoader.load(from:)` and `ShapeLoader` behave as before (one compound of edges). `SPLINE` now loads in that path, flattened to straight edges at one ten-thousandth of the drawing diagonal; ellipses are still polylined. Bulged polyline arcs now share the contour segment geometry.
- Tests copy ezdxf-generated fixtures from SwiftDXF's test suite into `Tests/OCCTSwiftIOTests/Fixtures/DXF`.

## v2.0.0-beta.4 (2026-10-17)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.6.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

Moves the OCCTSwift dependency from `exact: "4.0.0-beta.5"` to `exact: "4.0.0-beta.6"`. No source change: the package builds and all tests pass unmodified against beta.6. Nothing in beta.6's breaks (`simd` removed from the public surface, `offsetWire` sign, `circularPattern` partial-angle stepping) reaches this package's call sites.

## v2.0.0-beta.3 (2026-10-10)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.5.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

Moves the OCCTSwift dependency from `exact: "4.0.0-beta.4"` to `exact: "4.0.0-beta.5"`. No source change: the package builds and all tests pass unmodified against beta.5. Nothing in beta.5's three breaks (`Shape.isEmptyShape` removed, `Shape.analyze(tolerance:)` wire ordering, `Shape.solid(from:)` on an open body) reaches this package's call sites.

## v2.0.0-beta.2 (2026-09-30)

**Pre-release. Same code as v2.0.0-beta.1; use this tag instead.** v2.0.0-beta.1 was cut at `ccf49c3`, then
deleted and recreated at `39abfc9` to fix the OCCTSwift pin (see below). Moving a published tag changes the commit
a version resolves to, so a consumer who had already resolved beta.1 gets a SwiftPM fingerprint mismatch
("does not match previously recorded value") on their next resolve
([#46](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/46)). beta.2 carries the exact same tree as the
current beta.1 (`39abfc9`) under a tag that has only ever pointed at one commit. Published tags, pre-releases
included, are not moved or deleted from here on; a fix ships as the next number.

## v2.0.0-beta.1 (2026-09-29)

**Pre-release, pinned exactly to OCCTSwift 4.0.0-beta.4.** A consumer only gets this by naming it; the stable line stays at v1.8.0.

**`ShapeLoadResult`'s GD&T element types change (breaking).** OCCTSwift 4.0.0 replaces the untyped
`DimensionInfo`, `GeomToleranceInfo` and `DatumInfo` with the typed `Document.Dimension`,
`Document.GeomTolerance` and `Document.Datum` ([OCCTSwift#996](https://github.com/SecondMouseAU/OCCTSwift/issues/996)).
`ShapeLoadResult.dimensions`, `.geomTolerances` and `.datums`, and their initializer parameters, now use the
new types, so the major version moves. `Document.Dimension.value` is `Double?` and a range dimension reports
its bounds through `.bounds`, so code that read the old flat fields needs to switch on `bounds`.

**Dep bump:** `OCCTSwift from: "3.0.0"` to `exact: "4.0.0-beta.4"`. Exact, not `from:`, because `v4.0.0-kernel.N` tags are pre-releases of the same package that sort above every beta, so `from: "4.0.0-beta.4"` resolves to the newest kernel tag (main's source) rather than the beta. The other OCCTSwift 4.0.0 breaks
(`docs/SEMVER.md#v400`) have no call sites in this repo. Verified: `swift build --build-tests` clean and the
full suite passes against the real beta.4 checkout.

## v1.8.0 (2026-08-21)

**New public type: `DirectoryWatcher`.** Watches a file or directory for create/modify events
and invokes a caller-supplied closure, backed by kqueue. Closes [#42](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/42).

The agent-viewport selection bridge (`SecondMouseAU/ecosystem#53`) needs both an interactive
host and an MCP tool to notice a changed sidecar JSON file without polling on a fixed timer. The
only existing implementation of this technique in the ecosystem was `ScriptWatcher.swift`
(kqueue-based, macOS-only), living in `OCCTSwiftViewport`'s demo app rather than as a public
library component. `DirectoryWatcher` ports that proven approach into a standalone type with no
Viewport dependency, so `OCCTMCP`, `OCCTSwiftInteraction`, and (transitively) `OCCTSwiftUX` can
all depend on it without a new dependency edge.

Two behaviors go beyond a bare kqueue wrapper:

- Starting on a path that does not exist yet is not an error: the watcher falls back to
  watching the nearest existing ancestor directory, then switches to watching the target
  directly once it is created.
- When the watched path is a directory, dotfile entries (names starting with `.`) are ignored,
  so a write-to-hidden-temp-name-then-rename-into-place sequence (`.incoming-x.json` renamed to
  `x.json`) produces exactly one notification, for the final name.

macOS-only: kqueue is a Darwin primitive, and this package's platform floor also spans
iOS/visionOS/tvOS, so the whole file is gated `#if os(macOS)`. `Package.swift`'s platform floor
is unchanged; the type is simply absent on the other three platforms.

## v1.7.8 (2026-08-19)

**Repin OCCTSwift floor to 3.0.0.** OCCTSwift's v3.0.0 ([`docs/SEMVER.md#v300`](https://github.com/SecondMouseAU/OCCTSwift/blob/v3.0.0/docs/SEMVER.md#v300)) is a Rule 2 major on a much smaller surface than v2.0.0. OCCT itself does not move: the kernel stays at 8.0.1, rebuilt as `v3.0.0-kernel.1` to carry two patches the v2.0.0 asset was missing ([#905](https://github.com/SecondMouseAU/OCCTSwift/issues/905)/[#913](https://github.com/SecondMouseAU/OCCTSwift/issues/913)). Three breaks, all compile errors, audited against every call site here ([#38](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/38)):

- `Selector.SubShapeType.compsolid` renamed `.compSolid`, and `Shape.ShapeFilterType.RawValue` moving from `Int32` to `Int` as `ShapeFilterType` becomes a `ShapeType` typealias (both [#844](https://github.com/SecondMouseAU/OCCTSwift/issues/844)): zero hits in this repo.
- `Shape.bounds`/`size`/`center`, `Wire.bounds`, `Edge.bounds` and `Face.bounds`/`exactBounds` became Optional ([#943](https://github.com/SecondMouseAU/OCCTSwift/issues/943)), so a void bounding box stops fabricating `(0,0,0)-(0,0,0)`. This one bit, in the **test target only**: `DXFLoaderTests` (two sites) and `JWWLoaderTests` (one) read `shape.bounds` on a loaded compound. Each now unwraps through the `try #require` it already sat behind, deliberately not `?? .zero`, because a void bounding box has to fail the assertion rather than read as a zero-size drawing at the world origin.

Worth recording for the rest of the fanout: `swift build` alone reports this repin clean, because it does not compile test targets. The break only surfaces under `swift build --build-tests` or `swift test`.

`Sources/` never reads any of the six accessors, so the shipped library is unchanged: no public API or behaviour change here, and consumers need no migration.

## v1.7.7 — 2026-08-10

**Repin OCCTSwift floor to 2.0.0.** OCCTSwift's v2.0.0 ([`docs/SEMVER.md#v200`](https://github.com/SecondMouseAU/OCCTSwift/blob/main/docs/SEMVER.md#v200)) is a correctness major (Pass 1a/1b duplication+bug-fix audit, [#377](https://github.com/SecondMouseAU/OCCTSwift/issues/377)/[#669](https://github.com/SecondMouseAU/OCCTSwift/issues/669); OCCT absorbed to 8.0.1), 17 breaking API changes (12 compile errors, 5 silent value changes). Audited this package's call sites against the full break table, including the sub-shape-enumeration (#541/#568/#613/#502) and AAG (#642/#699) families a first-pass grep at issue-filing time hadn't covered: zero hits anywhere. `Sources/OCCTSwiftIO/ShapeLoader.swift`'s `subShapes(ofType: .solid)` was already `TopExp::MapShapes`-backed and deduplicated before this release, the exact convention #502 generalized elsewhere, not something that changed under it. Ecosystem-wide floor bump; no API or behaviour change here.

## v1.7.6 — 2026-07-30

**Repin OCCTSwift floor to 1.17.0.** Picks up Pass 1a of OCCTSwift's [#377/#380](https://github.com/SecondMouseAU/OCCTSwift/issues/377) duplication/bug-fix audit: nine duplicated continuity enums consolidated into two (source-compatible via deprecated-alias shims), several dedup cleanups, and edge-case bug fixes (arc-length failure sentinels, `Surface.normal` at singularities, `Curve2D.circle` at radius zero). One real API break — `Surface.drawMesh`/`evaluateGrid` now return a `SurfaceGrid` struct instead of `[[SIMD3<Double>]]` — is unused in this repo (grep-verified). Ecosystem-wide floor bump; no API or behaviour change here.

## v1.7.5 — 2026-07-20

**Migrate off deprecated `TopologyGraph` → `BRepGraph`.** OCCTSwift renamed its core graph class from `TopologyGraph` to `BRepGraph` in [OCCTSwift#335](https://github.com/SecondMouseAU/OCCTSwift/pull/335) (v1.15.0), keeping a deprecated `typealias TopologyGraph = BRepGraph` for source compatibility. Closes [#27](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/27).

`Sources/OCCTSwiftIO/MLExport.swift`'s `extension TopologyGraph { ... }` (the `exportForML()` / `exportJSON()` / `GraphExport` ML export layer) now reads `extension BRepGraph`, plus the matching test suite (`BRepGraphMLExportTests`) and docs. No public API or behaviour change: `TopologyGraph` remains callable (deprecated, with a compiler warning) since it names the same underlying type; this just stops OCCTSwiftIO's own source from routing through the deprecated name.

Also fixed a pre-existing doc bug in `docs/guides/cookbook/ml-export.md` and `docs/reference/GraphExport.md`: both called a `shape.topologyGraph()` convenience method that has never existed on `Shape` in OCCTSwift (the same bug was independently caught and fixed upstream in OCCTSwift's own docs the same day, commit `cf57630`). Examples now use the real, failable `BRepGraph(shape:)` initializer.

OCCTSwift dependency floor (`from: "1.12.9"`) already permits 1.15.0 as an open semver range — no `Package.swift` change needed. Verified building and testing against OCCTSwift 1.15.0 via a refreshed `Package.resolved`.

## v1.7.4 — 2026-07-20

**Repin OCCTSwift floor to 1.12.9.** OCCTSwift v1.12.8 added kernel patch 0006 (a `BRepGProp_EdgeTool` null-curve-on-surface guard, [OCCTSwift#318](https://github.com/SecondMouseAU/OCCTSwift/issues/318)) and v1.12.9 added patches 0007 through 0009 (free-bounds `lwire` reset, boolean-path BSpline O(1) periodic normalization, and STEP-writer oversized-string split; [OCCTSwift#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323)), on top of the earlier fillet, free-bounds, and ShapeFix_Face patches. Ecosystem-wide floor bump; no API or behaviour change.

## v1.7.3 — 2026-07-19

**Repin OCCTSwift floor to 1.12.7.** OCCTSwift v1.12.7 carries OCCT kernel patch 0005: `ShapeFix_Face::FixPeriodicDegenerated` guards a null `Context()`, fixing the SIGSEGV in [OCCTSwift#317](https://github.com/SecondMouseAU/OCCTSwift/issues/317) (upstream [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380)), on top of the free-bounds (#310) and thread-safe-fillet (#298) patches. Ecosystem-wide floor bump so no consumer transitively resolves a pre-fix OCCTSwift. No API or behaviour change.

## v1.7.2 — 2026-07-19

**Repin OCCTSwift floor to 1.12.6.** OCCTSwift v1.12.6 carries OCCT kernel patch 0004 — `ShapeAnalysis_FreeBounds` no longer returns a null `owires` on empty input, fixing the uncatchable free-bounds SIGSEGV ([OCCTSwift#310](https://github.com/SecondMouseAU/OCCTSwift/issues/310), upstream [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377)) — on top of the thread-safe-fillet patch 0003 (#298). Ecosystem-wide floor bump so no consumer transitively resolves a pre-fix OCCTSwift. No API or behaviour change.

## v1.7.1 — 2026-07-18

**Repin OCCTSwift floor to 1.12.3.** OCCTSwift v1.12.3 fixes non-reentrant 3D fillet/chamfer statics in the OCCT kernel (carried patch 0003 — [OCCTSwift#298](https://github.com/SecondMouseAU/OCCTSwift/issues/298) / upstream [OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374)): concurrent fillet builds no longer corrupt each other into wrong-but-plausible solids. Ecosystem-wide floor bump so no consumer of this package can transitively resolve a pre-fix OCCTSwift. No API or behaviour change here.

## v1.7.0 — 2026-07-18

**`ShapeLoader` splits a multibody file into one entry per body.** Closes [#21](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/21).

OCCTSwift v1.11.3 fixed a silent data-loss bug in the robust importers: before it, `loadSTLRobust`
(and `loadRobust` / `loadWithDiagnostics`) dropped every body after the first, so a 10-body file came
back as 1 solid ([OCCTSwift#302](https://github.com/SecondMouseAU/OCCTSwift/issues/302)). It now returns
a **compound of solids** for a multibody file, a plain **solid** for a single-body one.

`ShapeLoader`'s STL / OBJ / BREP / IGES paths wrapped whatever they got in a **single** `shapesWithColors`
entry, so post-fix they lumped a whole compound-of-solids into one entry — inconsistent with the STEP
path, which has always returned one entry per body via `Document.shapesWithColors()`. A consumer got N
bodies from a STEP assembly but 1 lumped body from the equivalent STL, collapsing per-body selection,
colour and metadata.

**Change:** these paths now return **one entry per body**. A `.solid` result stays a single entry; a
compound is split into its solids; a result with no solids (a raw-mesh STL that loaded as loose faces)
stays a single entry. No API change — same `shapesWithColors` shape, more entries.

Minimum OCCTSwift bumped to **1.11.3** (the split has nothing to split without the #302 fix).

## v1.6.0 — 2026-07-16

**`MeshIO.Mesh` carries PMX material groups.** Closes [#17](https://github.com/gsdali/OCCTSwiftIO/issues/17).

Previously `MeshIO`'s PMX adapter discarded SwiftPMX 1.1.0's `Mesh.submeshes` — the material section's
per-material index ranges — so a consumer had no way to isolate one part of a whole-model PMX (e.g. a
vehicle's carbody skin out of the full fused mesh) without bypassing `MeshIO` and consuming `SwiftPMX`
directly.

**New public API** (additive; existing consumers unaffected):

- `struct Submesh` — `indexOffset` / `indexCount` / `materialIndex`, one per source-file material.
- `Mesh.submeshes: [Submesh]` — empty for formats/files with no such grouping; populated for PMX.

**Dependencies:** `SwiftPMX` bumped `from: "1.0.0"` → `from: "1.1.0"` (the release that added
`Mesh.submeshes`).

Out of scope (noted, not requested): `SwiftX` (`.x`) has the same structural gap — it fuses every
`Mesh` block in a file into one buffer with no per-block grouping exposed — but no `.x` model in the
corpus needed a sub-part isolated yet, so `MeshIO`'s `.x` adapter is unchanged.

## v1.5.0 — 2026-06-26

**New format: DXF (AutoCAD Drawing Interchange Format)** — entity-level read (geometry + TEXT + layers), alongside the existing JWW path. Closes [#11](https://github.com/gsdali/OCCTSwiftIO/issues/11).

**Entity model (primary).** `import OCCTSwiftIO` now re-exports [SwiftDXF](https://github.com/SecondMouseAU/SwiftDXF), so the neutral `DXF.Drawing` / `DXF.Entity` model is in scope directly. `DXFLoader.readEntities(from:)` returns it. The model preserves what DXF actually carries — geometry (`LINE`/`CIRCLE`/`ARC`/`ELLIPSE`/`LWPOLYLINE`/`POLYLINE` with per-vertex bulge), `TEXT`/`MTEXT` (insertion point **and** string), **per-entity layer name**, and header essentials (`$INSUNITS`, `$EXTMIN`/`$EXTMAX`).

**OCCT `Shape` convenience.** `CADFileFormat.dxf` (extension `dxf`); `ShapeLoader` also builds a compound of OCCT edges in the Z=0 plane (lines/circles/arcs/ellipses/bulged-polylines → edges; points → vertices; text skipped) — same shape as the JWW path. No B-Rep solid; the entity model, not the `Shape`, is the source of truth for DXF.

**Reader.** Pure-Swift SwiftDXF (MIT), validated bit-exact against the MIT-licensed `ezdxf` reference reader — entity counts and every coordinate scalar — across an 11-file / ~62k-entity corpus.

## v1.0.0 — 2026-05-08

OCCTSwift dependency bumped to **`from: "1.0.1"`** (OCCT 8.0.0 GA pin). No public API changes in this package — pure dep bump to graduate alongside [OCCTSwift v1.0.0](https://github.com/gsdali/OCCTSwift/releases/tag/v1.0.0). SemVer-stable from this tag.

Closes [#3](https://github.com/gsdali/OCCTSwiftIO/issues/3).

## v0.2.0 — 2026-05-07

ML-export hoist from OCCTSwift per [OCCTSwiftIO#1](https://github.com/gsdali/OCCTSwiftIO/issues/1) (supersedes [OCCTSwift#71](https://github.com/gsdali/OCCTSwift/issues/71)). The consumption-side ML repacking layer added to OCCTSwift in v0.136.0 — pure batch / headless workflow, no Viewport — fits this package's charter, so it lives here now.

**New public API** (extension on `OCCTSwift.TopologyGraph`):

- `struct GraphExport` — flat vertex positions + per-edge boundary/manifold flags + COO-format face/edge/vertex incidence + face-to-face adjacency.
- `func exportForML() -> GraphExport` — build the export from a `TopologyGraph`.
- `func exportJSON() -> Data?` — JSON serialization for ML pipelines.

**What did not move** (and why):

- `FaceGridSample` / `sampleFaceUVGrid(faceIndex:uSamples:vSamples:)` stay in OCCTSwift. Their implementation calls `OCCTBRepGraphSampleFaceUVGrid` on `TopologyGraph.handle`, which is `internal` to the OCCTSwift module — lifting them would require widening kernel visibility, which the partial-lift decision on issue #1 rules out as out-of-scope.
- `sampleEdgeCurve(edgeIndex:count:)` similarly stays — same `handle` constraint.

**Breaking change for OCCTSwift consumers:** the `TopologyGraph.exportForML / exportJSON` symbols have been deleted from OCCTSwift (kernel release coordinated separately). Direct callers must now `import OCCTSwiftIO` in addition to `import OCCTSwift`. Symbol resolution otherwise unchanged. Known callers swept: `OCCTSwiftScripts/Sources/occtkit/Commands/GraphML.swift`, `OCCTSwiftScripts/Sources/GraphML/main.swift`.

**Dependencies:** `OCCTSwift` ≥ `0.171.0` (the kernel release that ships the matching deletion).

## v0.1.0 — 2026-05-06

Initial release. Spin-out of file-I/O concerns from [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) per [OCCTSwiftTools#12](https://github.com/gsdali/OCCTSwiftTools/issues/12) so headless consumers (Scripts, PadCAM CLI, batch pipelines) don't drag in `OCCTSwiftViewport` transitively just to load a STEP file.

**Public API:**

- `enum ShapeLoader` — `load(from:format:progress:)`, `loadRobust(...)`, `loadFromManifest(at:)`. Returns `ShapeLoadResult { shapesWithColors, dimensions, geomTolerances, datums, manifest }`.
- `enum CADFileFormat` — `.step`, `.stl`, `.obj`, `.brep`, `.iges` (lifted from OCCTSwiftTools).
- `enum ExportManager` + `enum ExportFormat` — OBJ / PLY / STEP / BREP / glTF / GLB writers (lifted from OCCTSwiftTools).
- `struct CADBodyMetadata` — pure-data per-body picking metadata (face / edge / vertex indices). Produced by `OCCTSwiftTools.CADFileLoader.shapeToBodyAndMetadata`; lives here so the type itself doesn't carry a Viewport dep.
- `struct ScriptManifest` — Codable manifest format for the script harness (lifted from OCCTSwiftTools).
- `final class ImportProgressClosure` — closure-backed `OCCTSwift.ImportProgress` adapter (lifted from OCCTSwiftTools).

**What's not here:**

- `ViewportBody` production. That's `OCCTSwiftTools.CADFileLoader.shapeToBodyAndMetadata` — one floor up — and is the entire reason this package exists separately.
- `CADLoadResult { bodies: [ViewportBody], ... }`. Stays in OCCTSwiftTools where the Viewport dep already lives.

**Dependencies:**

- `OCCTSwift` ≥ `0.170.1`.

**Platform floor:** iOS 18 / macOS 15 / visionOS 1 / tvOS 18 — matches OCCTSwiftTools so consumers using both don't have to reconcile floors.

**Test invocation:** `OCCT_SERIAL=1 swift test --parallel --num-workers 1`. The env var + serial workers are required, not optional, due to a known NCollection container-overflow race in OCCT on arm64 macOS.
