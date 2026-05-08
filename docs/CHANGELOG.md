# Changelog

Most recent first. Pre-1.0: free to break; deprecations documented here. SemVer-stable from v1.0.0.

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
