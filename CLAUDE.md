# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo state

`v0.1.0` is the spin-out of file-I/O concerns from [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) per [OCCTSwiftTools#12](https://github.com/gsdali/OCCTSwiftTools/issues/12). The point: headless consumers (Scripts, PadCAM CLI, batch pipelines) shouldn't drag in `OCCTSwiftViewport` transitively just to load a STEP file.

Files in `Sources/OCCTSwiftIO/`:

- `ShapeLoader` — STEP / IGES / STL / OBJ / BREP / manifest → `ShapeLoadResult` (shapes + colors + AP242 metadata, **no bodies**).
- `ExportManager` — OBJ / PLY / STEP / BREP / glTF / GLB writers.
- `CADFileFormat`, `ExportFormat` — format enums.
- `CADBodyMetadata` — pure-data type (face/edge/vertex pick indices). Produced by `OCCTSwiftTools.CADFileLoader.shapeToBodyAndMetadata` on the bridge side; lives here so it doesn't carry a Viewport dep.
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
OCCT_SERIAL=1 swift test --parallel --num-workers 1   # MUST run serially
swift test --filter OCCTSwiftIOTests.SuiteName/testName   # single test
```

`OCCT_SERIAL=1` + serial workers is **required** — known NCollection container-overflow race in OCCT on arm64 macOS. Inherited from OCCTSwift; do not "fix".

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
