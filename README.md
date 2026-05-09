# OCCTSwiftIO

[![License](https://img.shields.io/badge/license-LGPL--2.1-blue)](LICENSE)

Headless CAD file I/O for [OCCTSwift](https://github.com/gsdali/OCCTSwift) — STEP, IGES, STL, OBJ, BREP loaders + glTF/GLB/OBJ/PLY/STEP/BREP exporters. **No Viewport dependency** — safe to use from CLIs, batch pipelines, and server-side workflows that don't need a Metal renderer.

Part of the [OCCTSwift ecosystem](https://github.com/gsdali/OCCTSwift/blob/main/docs/ecosystem.md) — see the ecosystem map for how this package fits with the kernel, viewport, and sibling layers.

> Status: **v1.0.0**. Spun out of [OCCTSwiftTools#12](https://github.com/gsdali/OCCTSwiftTools/issues/12) so headless consumers don't drag in OCCTSwiftViewport transitively. SemVer-stable from this tag.

## What it does

```swift
import OCCTSwift
import OCCTSwiftIO

// Load a STEP assembly into shapes + per-shape colors + AP242 dimensions/datums.
let result = try await ShapeLoader.load(from: stepURL, format: .step)
for (shape, color) in result.shapesWithColors {
    // ...
}

// Export to glTF / OBJ / STEP / BREP / PLY / GLB.
try await ExportManager.export(shapes: result.shapes, format: .glb, to: outURL)
```

For body-producing loaders (CPU mesh + interleaved vertex buffer + face/edge/vertex pick data for AIS), use [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) which wraps this package with the bridge layer.

## Architecture position

```
OCCTSwiftAIS          (selection / manipulators / dimensions; depends on Tools)
       ↑
OCCTSwiftTools        (bridge — Shape ↔ ViewportBody)
   ↑       ↑
   |   OCCTSwiftViewport  (Metal renderer)
   |
OCCTSwiftIO           ← this repo (headless file I/O)
       ↑
OCCTSwift             (B-Rep modeling kernel)
```

`OCCTSwiftIO` depends on **OCCTSwift only**. No transitive Viewport.

## Installation

```swift
.package(url: "https://github.com/gsdali/OCCTSwiftIO.git", from: "0.1.0"),
```

## Supported platforms

| Platform | Status |
|---|---|
| macOS 15+ arm64 | Supported |
| iOS 18+ device + simulator arm64 | Supported |
| visionOS 1+ device + simulator arm64 | Supported |
| tvOS 18+ device + simulator arm64 | Supported |

Floor matches OCCTSwiftTools — change in lockstep if either moves.

## Build & test

```bash
swift build
OCCT_SERIAL=1 swift test --parallel --num-workers 1
```

`OCCT_SERIAL=1` + serial workers are **required** — there's a known NCollection container-overflow race in OCCT on arm64 macOS that segfaults parallel test runs. Inherited from OCCTSwift; do not "fix" by re-enabling parallelism.

## License

[LGPL 2.1](LICENSE) — matches OCCTSwift / OCCTSwiftTools.
