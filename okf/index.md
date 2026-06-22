---
type: repo
title: OCCTSwiftIO
resource: https://github.com/SecondMouseAU/OCCTSwiftIO
tags: [cad, occt, io, step, gltf, headless, swift, kernel]
description: Headless CAD file I/O for OCCTSwift — STEP/IGES/STL/OBJ/BREP loaders plus glTF/GLB/OBJ/PLY/STEP/BREP exporters, with no Viewport dependency.
timestamp: 2026-06-22
---

# OCCTSwiftIO

> Headless CAD file import/export for the OCCTSwift ecosystem. Loads STEP (with AP242
> dimensions/datums and per-shape colors), IGES, STL, OBJ, and BREP; exports glTF, GLB, OBJ, PLY,
> STEP, and BREP. It pulls in **OCCTSwift only** — no Metal renderer — so it is safe to use from
> CLIs, batch pipelines, and server-side workflows. Spun out of OCCTSwiftTools so headless
> consumers don't drag in OCCTSwiftViewport transitively.

## Role in the ecosystem

- **Cluster:** kernel
- **Depends on:** [OCCTSwift](https://github.com/SecondMouseAU/OCCTSwift) — the B-Rep modelling
  kernel (floored at v1.7.1). No transitive Viewport dependency.
- **Feeds:** [OCCTSwiftTools](https://github.com/SecondMouseAU/OCCTSwiftTools), which wraps this
  package's loaders with the bridge layer to produce viewport-ready bodies + pick metadata.

## Components

See [`components/`](components/index.md) for the public surface (`ShapeLoader`, `ExportManager`,
and the supported format enums).

## References

See [`references/`](references/index.md) for the changelog, the Swift Package Index page, and
OpenCASCADE upstream.

## Notes

- Published to the Swift Package Index via `.spi.yml` (documentation target `OCCTSwiftIO`).
- Tests must run serially (`OCCT_SERIAL=1`, single worker) due to an inherited OCCT NCollection
  race on arm64 macOS.
- LGPL-2.1, matching OCCTSwift / OCCTSwiftTools.
