# Changelog

Most recent first. Pre-1.0: free to break; deprecations documented here. SemVer-stable from v1.0.0.

> Note: v1.1.0–v1.4.1 (MeshIO / 3MF / glTF / JWW) shipped as tagged GitHub releases without entries here; this log resumes at v1.5.0.

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
