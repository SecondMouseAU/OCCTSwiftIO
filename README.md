# OCCTSwiftIO

[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSecondMouseAU%2FOCCTSwiftIO%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/SecondMouseAU/OCCTSwiftIO)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSecondMouseAU%2FOCCTSwiftIO%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/SecondMouseAU/OCCTSwiftIO)
[![License](https://img.shields.io/badge/license-LGPL--2.1-blue)](LICENSE)
[![Docs](https://img.shields.io/badge/docs-page-2ea44f)](https://secondmouseau.github.io/OCCTSwiftIO/)

📖 **Documentation:** <https://secondmouseau.github.io/OCCTSwiftIO/>

Headless file I/O for the [OCCTSwift](https://github.com/SecondMouseAU/OCCTSwift) ecosystem. **No
Viewport dependency**: safe for CLIs, batch pipelines, and server-side workflows. The package ships
**two products** so consumers take only what they need:

| Product | Depends on OCCT? | What it's for |
|---|---|---|
| **`MeshIO`** | **No** (pure Swift) | 3D **mesh** formats → a neutral `Mesh` (positions + indices). |
| **`OCCTSwiftIO`** | Yes | **CAD B-Rep** load/export as OCCT `Shape`s, plus **2D vector drawings** (JWW, DXF, DWG) as edges or as entities. |

The split lets OCCT-free consumers (e.g. a raw-mesh pipeline) read meshes without pulling in the 1.3 GB
kernel. The two products are independent: `OCCTSwiftIO` does not depend on `MeshIO`, so taking it does
not build the mesh-format stack (ThreeMF and its C++ interop, SwiftGLTF, SwiftPMX, SwiftX).

## Format coverage

`MeshIO` reads STL, OBJ, PLY, glTF / GLB, 3MF, PMX and DirectX `.x`, and writes all but PMX and `.x`.
`OCCTSwiftIO` reads STEP, IGES, BREP, STL and OBJ as OCCT shapes and the 2D vector formats JWW, DXF
and DWG, and writes STEP, BREP, OBJ, PLY, glTF and GLB. [Formats](docs/formats.md) has the full
table, the backend for each format and the per-format notes.

## Install

```swift
dependencies: [
    .package(url: "https://github.com/SecondMouseAU/OCCTSwiftIO.git", from: "1.8.0"),
],
// then add the product(s) you need:
.target(name: "YourTarget", dependencies: [
    .product(name: "MeshIO", package: "OCCTSwiftIO"),        // mesh, no OCCT
    .product(name: "OCCTSwiftIO", package: "OCCTSwiftIO"),   // CAD + 2D drawings (pulls OCCT)
]),
```

`from: "1.8.0"` takes the stable 1.x line, which was at 1.8.0 when this was written; the
[Releases](https://github.com/SecondMouseAU/OCCTSwiftIO/releases) page has the current one. Most of
the 2D drawing work described below is not in it: `DrawingLoader`, DWG, `DXFLoader.loadContours`,
block expansion and `ShapeLoadResult.warnings` for a DXF, and a JWW at full size are in the 2.0.0
pre-releases only (as is `OCCTSwiftIO` building without `MeshIO`). Take one by naming its tag
exactly, with `exact:`, since a pre-release can change between builds.

## MeshIO: pure-Swift mesh I/O

```swift
import MeshIO

let mesh = try MeshIO.load(contentsOf: url)        // .stl/.obj/.ply/.gltf/.glb/.3mf/.pmx/.x
print(mesh.vertexCount, mesh.triangleCount, mesh.bounds as Any)

try MeshIO.write(mesh, to: outURL)                 // format inferred from extension
try MeshIO.write(mesh, to: stlURL, format: .stl, asciiSTL: true)
```

`Mesh` is a value type (`positions: [SIMD3<Float>]`, `indices: [UInt32]`, `submeshes: [Submesh]`). PMX
carries its material sections through as `submeshes` (empty for every other format, including `.x`):
isolate one part of a whole-model PMX with `sub.indexOffset ..< sub.indexOffset + sub.indexCount`. PMX/`.x`
are read via the standalone [SwiftPMX](https://github.com/SecondMouseAU/SwiftPMX) /
[SwiftX](https://github.com/SecondMouseAU/SwiftX) packages; 3MF via
[ThreeMF](https://github.com/tomasf/ThreeMF); glTF read via
[SwiftGLTF](https://github.com/schwa/SwiftGLTF) (write is native).

## OCCTSwiftIO: CAD + JWW + DXF + DWG

```swift
import OCCTSwift
import OCCTSwiftIO

// STEP / IGES / BREP → shapes + colors + AP242 metadata.
let result = try await ShapeLoader.load(from: stepURL, format: .step)

// JWW (Jw_cad 2D drawing) → a compound of OCCT edges (lines, arcs/circles, points), at full size.
let drawing = try await ShapeLoader.load(from: jwwURL, format: .jww)

// DXF → the same: one compound of curve edges (lines, arcs, circles, ellipses, splines).
let dxf = try await ShapeLoader.load(from: dxfURL, format: .dxf)

// DWG → the same compound of edges, read in process (no tool to install).
let dwg = try await ShapeLoader.load(from: dwgURL, format: .dwg)
dwg.warnings   // what was not read, as DrawingLoader reports it; block references are expanded

// Export shapes to STEP / BREP / OBJ / PLY / glTF / GLB.
try await ExportManager.export(shapes: result.shapes, format: .glb, to: outURL)
```

### One call for 2D drawings

`DrawingLoader.read(from:)` reads a DXF, a DWG or a JWW and returns one `DrawingResult`, so a
consumer neither picks a reader nor branches on the extension. The format comes from the file's
bytes.

```swift
let result = try DrawingLoader.read(from: url)
result.drawing   // DXF.Drawing: entities (including hatches and leaders), layers, units, extents, block references
result.source    // file name, SHA-256, format, and the format's own version
result.warnings  // what was skipped by type and layer, could not be read, or assumed, as data
result.drawing.identities[i]   // a stable identity for entity i: its DXF handle, else its position
result.rebuiltDimensions       // JWW: the dimensions rebuilt from loose pieces, by identity, with their pieces
result.unexplainedDimensionValues   // JWW: dimension values that are not dimensions, at full size
result.layerGroupScales        // JWW: each layer group's scale, multiplied out (80 for 1:80)
```

DWG is read by [SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG) in process, with no tool to
install, JWW through SwiftJWW at full size with the dimensions it rebuilds from loose pieces, DXF
directly.
Block references are expanded by default, each expanded entity's identity listing the references
it came through, so a title block can be kept or dropped by name; pass
`.init(expandBlocks: false)` to leave them. `.hatch` and `.leader` are entity cases (boundary loops,
and vertices with the annotation handle), `layers` and `lineTypes` are the file's tables, and a
spline or ellipse can be turned into lines and arcs within a tolerance with
`entity.fitted(tolerance:)`. A `DIMENSION` carries `rotation`, a `computedMeasurement`
(`measurement` is `nil` when the file stored none), its style's precision, and its text split into
parts. These come from [SwiftDXF](https://github.com/SecondMouseAU/SwiftDXF) 0.4.0 or later.

### DWG

[SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG) (MIT) reads a DWG in process: there is no tool
to build or install, and nothing to find at run time. `import OCCTSwiftIO` brings its `DWG`
namespace into scope, so a `DWG.Error` can be caught by name. It reads R2000 to R2018 and, for simple
entities, R14; R12 and earlier throw `DWG.Error.unsupportedVersion`. It does not read every
entity, and a corrupt file is not proved safe for every byte: what it cannot read is counted and
reported as a `DrawingWarning`. The limits, what throws, and how corrupt files are checked are in
the [DWGLoader reference](docs/reference/DWGLoader.md#limits-that-matter-to-a-caller).

SwiftDWG is a Swift port of the DWG reader in [ACadSharp](https://github.com/DomCR/ACadSharp) (MIT),
together with the Open Design Alliance's published specification of the format. It is not a
clean-room implementation, and says so in its README and `NOTICE.md`.

### DXF closed regions as faces

`DXFLoader.loadContours(from:options:)` builds one planar face per closed region, with islands and
holes nested and subtracted, in millimetres. Chaining, nesting, unit conversion and the fitting of
ellipses and splines are done by [SwiftDXF](https://github.com/SecondMouseAU/SwiftDXF) (0.3.0 or
later, OCCT-free); this package turns the result into OCCT edges, wires and faces. Arcs stay true
circular arcs and lines stay lines.

```swift
let result = try DXFLoader.loadContours(from: dxfURL, options: .init(layers: ["CUT"]))
for item in result.faces {
    item.face        // Shape: planar face in Z=0, holes subtracted
    item.outerWire   // Wire, counter-clockwise
    item.holeWires   // [Wire]
    item.area        // analytic area, mm^2
}
result.openChains    // segments that never closed (data, not an error)
result.warnings      // SwiftDXF warnings: units assumed, curves fitted, text ignored, ...
result.unbuilt       // contour shapes OCCT could not build (normally empty)
```

`load(from:)` and `ShapeLoader` keep returning a single compound of edges, with block references
expanded and what was left out in `ShapeLoadResult.warnings`. Within it, `SPLINE` and `ELLIPSE` are
fitted to lines and circular arcs, within one ten-thousandth of the drawing diagonal in the drawing's
own units, so a spline that is really a line or an arc comes back as that one edge; use
`loadContours` when you want planar faces, with the fit held to a tolerance in millimetres.

For body-producing loaders (CPU mesh + pick data for AIS), use
[OCCTSwiftTools](https://github.com/SecondMouseAU/OCCTSwiftTools), which wraps this package.

## Architecture position

```
OCCTSwiftTools     (bridge: Shape ↔ ViewportBody)
       ↑
OCCTSwiftIO        ← this repo (headless file I/O)        MeshIO  ← pure-Swift mesh (no OCCT)
       ↑                                                     ↑
OCCTSwift          (B-Rep kernel)              SwiftPMX / SwiftX / ThreeMF / SwiftGLTF / SwiftJWW / SwiftDXF / SwiftDWG
```

**Hard rule: no Viewport dependency in this package.** Produce `ViewportBody`s in OCCTSwiftTools.

## License

LGPL-2.1 (inherited from OCCTSwift / OCCT). The mesh-format reader packages carry their own permissive
licenses (MIT / BSD-3).
