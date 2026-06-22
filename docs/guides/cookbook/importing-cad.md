---
title: Importing a CAD file
parent: Cookbook
nav_order: 1
---

# Importing a CAD file

`ShapeLoader` loads STEP / IGES / BREP / STL / OBJ / JWW into OCCT `Shape`s plus document metadata,
with no Viewport dependency. The entry points are `async throws` static methods on the `ShapeLoader`
enum; both return a `ShapeLoadResult`.

## Pick the format

A `CADFileFormat` selects the per-format code path. You can hard-code it, or detect it from the file
extension:

```swift
import OCCTSwift
import OCCTSwiftIO

guard let format = CADFileFormat(fileExtension: url.pathExtension) else {
    throw CocoaError(.fileReadUnsupportedScheme)   // unrecognised extension
}
let result = try await ShapeLoader.load(from: url, format: format)
```

`CADFileFormat(fileExtension:)` accepts `step`/`stp`, `stl`, `obj`, `brep`/`brp`, `iges`/`igs`, and
`jww` (case-insensitive), returning `nil` for anything else.

## Read shapes, colors, and AP242 metadata

```swift
let result = try await ShapeLoader.load(from: stepURL, format: .step)

// Shapes paired with their per-shape color (nil for formats that carry none).
for (shape, color) in result.shapesWithColors {
    print(shape, color as Any)
}

// Or just the shapes, dropping color info:
let shapes = result.shapes

// AP242 GD&T (STEP only; empty otherwise):
print(result.dimensions, result.geomTolerances, result.datums)
```

STEP carries per-shape colors and AP242 dimensions / tolerances / datums; STL, OBJ, BREP, and IGES
return shapes with `nil` colors and empty metadata arrays.

## Robust loading for messy files

STL and IGES files frequently ship with gaps OCCT's basic importer can't close. `loadRobust` routes
those two formats through the sewing/healing path (for STEP / OBJ / BREP it is identical to `load`):

```swift
let healed = try await ShapeLoader.loadRobust(from: igesURL, format: .iges)
```

## JWW (2D vector drawings)

JWW is a Jw_cad 2D drawing — not a solid or a mesh. It loads to a single **compound `Shape` of OCCT
edges** in the `Z = 0` plane (lines, circular arcs, ellipse polylines, and points):

```swift
let drawing = try await ShapeLoader.load(from: jwwURL, format: .jww)
let compound = drawing.shapes.first   // one compound of edges/vertices
```
