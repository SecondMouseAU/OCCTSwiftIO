# Changelog

Most recent first. Pre-1.0: free to break; deprecations documented here.

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
