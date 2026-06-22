---
type: component
title: Components index
resource: https://github.com/SecondMouseAU/OCCTSwiftIO
tags: [index]
description: Public modules / API surfaces exposed by OCCTSwiftIO.
timestamp: 2026-06-22
---

# Components

Public product/target from `Package.swift`, plus the key API surfaces from the README.

- **`OCCTSwiftIO`** (library product / target) — the single public module. Headless, no Viewport.
  - `ShapeLoader.load(from:format:)` — async loader returning shapes, per-shape colors, and AP242
    dimensions/datums. Supported input formats: STEP, IGES, STL, OBJ, BREP.
  - `ExportManager.export(shapes:format:to:)` — async exporter. Supported output formats: glTF,
    GLB, OBJ, PLY, STEP, BREP.

> For body-producing loaders (CPU mesh + interleaved vertex buffer + face/edge/vertex pick data),
> downstream consumers use [OCCTSwiftTools](https://github.com/SecondMouseAU/OCCTSwiftTools), which
> wraps this package with the bridge layer.
