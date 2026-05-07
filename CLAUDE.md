# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo state

`v0.1.0` is the spin-out of file-I/O concerns from [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) per [OCCTSwiftTools#12](https://github.com/gsdali/OCCTSwiftTools/issues/12). The point: headless consumers (Scripts, PadCAM CLI, batch pipelines) shouldn't drag in `OCCTSwiftViewport` transitively just to load a STEP file.

Load-bearing types in `Sources/OCCTSwiftIO/`:

- `ShapeLoader` — STEP / IGES / STL / OBJ / BREP / manifest → `ShapeLoadResult` (shapes + colors + AP242 metadata, **no bodies**).
- `ExportManager` — OBJ / PLY / STEP / BREP / glTF / GLB writers.
- `CADBodyMetadata` — pure-data type (face/edge/vertex pick indices). Produced by `OCCTSwiftTools.CADFileLoader.shapeToBodyAndMetadata` on the bridge side; lives here so the type itself doesn't carry a Viewport dep.
- `ScriptManifest` — Codable manifest format for the script harness.
- `ImportProgressClosure` — closure-backed `OCCTSwift.ImportProgress` for one-shot use.

## Architectural position

```
OCCTSwiftAIS          (depends on Tools)
       ↑
OCCTSwiftTools        (bridge: Shape ↔ ViewportBody — depends on IO + Viewport)
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

`OCCT_SERIAL=1` + serial workers is **required** — known NCollection container-overflow race in OCCT on arm64 macOS. Inherited from OCCTSwift; do not "fix".

`--filter` takes a regex over the test ID; use the Swift type name of the `@Suite` (e.g. `ShapeLoaderTests`), not the suite's display string.

## Behaviors worth knowing

These are non-obvious from type signatures and easy to get wrong:

- **AP242 metadata is STEP-only.** `ShapeLoadResult.dimensions / geomTolerances / datums` are populated only when loading STEP files via `Document.load`. Non-STEP formats (STL / OBJ / BREP / IGES) always return empty arrays — that's not a bug to fix, it's the format limitation.
- **`loadRobust` only differs for STL and IGES.** Those formats often ship with gaps that the basic importer can't close, so the robust path runs sewing/healing. For STEP / OBJ / BREP, `loadRobust` is identical to `load`.
- **Multi-shape export auto-numbers files.** `ExportManager.export(shapes:format:to:)` writes one file per shape when given >1 shape, inserting an index before the extension (`out.glb` → `out.0.glb`, `out.1.glb`, ...). Callers that expected a single combined file will be surprised.
- **Color is only carried by STEP.** STL / OBJ / BREP / IGES all return `color: nil` per shape — `shapesWithColors` still pairs them, but the color slot is empty.
- **Progress callbacks fire off the main thread.** `ImportProgressClosure` runs on whatever thread the importer used (usually a background thread under the async API). UI updates must hop to `@MainActor` explicitly.

## Platform floor

`Package.swift` pins `.iOS(.v18)`, `.macOS(.v15)`, `.visionOS(.v1)`, `.tvOS(.v18)` — matches OCCTSwiftTools so consumers using both don't have to reconcile. Could in principle relax to OCCTSwift's (15.0/12.0) since IO has no Viewport dep, but the practical consumer set lives at the Tools floor.

## Conventions cribbed from OCCTSwift

- **License**: LGPL 2.1 (matches OCCT / OCCTSwift / OCCTSwiftTools).
- **Swift**: tools-version 6.1, language mode `.v6`.
- **Tests**: Swift Testing (`@Suite` / `@Test` / `#expect`). Swift Testing **does not short-circuit** — never `#expect(x != nil); #expect(x!.isValid)`. Always `if let x { #expect(x.isValid) }`.
- **Test names must not shadow API method names** used inside the body — runner gets confused. Prefix `t_` or use descriptive English.
- **Versioning (pre-1.0)**: tiny additive features = patch bump. Minor for new public API surface. Free to break — document in `docs/CHANGELOG.md`.
- **Release pattern**: every shipped version commits + pushes + tags + creates a GitHub release with notes from CHANGELOG.

## What is explicitly out of scope

- Anything that produces `ViewportBody`. That's `OCCTSwiftTools`.
- Selection / picking / dimension widgets. That's `OCCTSwiftAIS` (two layers up).
- Headless ray tracing — use CADRays separately.
- Linux / Windows / Android / watchOS.

## Ecosystem context

- `~/Projects/OCCTSwift/CLAUDE.md` — kernel project conventions (this repo follows them).
- `~/Projects/OCCTSwiftTools/CLAUDE.md` — sibling that wraps this package with the bridge layer.
