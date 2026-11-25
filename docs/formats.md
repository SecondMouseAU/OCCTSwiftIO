---
title: Formats
nav_order: 4
---

# Formats

Everything the package reads and writes, by product. The README and the home page link here instead of repeating it.

| Format | Read | Write | Product | Backend |
|---|---|---|---|---|
| **STL** (ascii + binary) | ✅ | ✅ | MeshIO | native |
| **OBJ** | ✅ | ✅ | MeshIO | native |
| **PLY** | ✅ ascii + binary-LE | ✅ ascii | MeshIO | native |
| **glTF / GLB** | ✅ | ✅ | MeshIO | [SwiftGLTF](https://github.com/schwa/SwiftGLTF) (read) + native (write) |
| **3MF** | ✅ | ✅ | MeshIO | [ThreeMF](https://github.com/tomasf/ThreeMF) |
| **PMX** (MikuMikuDance) | ✅ | no | MeshIO | [SwiftPMX](https://github.com/SecondMouseAU/SwiftPMX) |
| **DirectX `.x`** | ✅ | no | MeshIO | [SwiftX](https://github.com/SecondMouseAU/SwiftX) |
| **STEP** | ✅ | ✅ | OCCTSwiftIO | OCCT |
| **IGES** | ✅ | no | OCCTSwiftIO | OCCT |
| **BREP** | ✅ | ✅ | OCCTSwiftIO | OCCT |
| **JWW** (Jw_cad, 2D vector) | ✅ | no | OCCTSwiftIO | [SwiftJWW](https://github.com/SecondMouseAU/SwiftJWW) → OCCT edges |
| **DXF** (AutoCAD, 2D vector, ASCII) | ✅ | no | OCCTSwiftIO | [SwiftDXF](https://github.com/SecondMouseAU/SwiftDXF) → OCCT edges, or planar faces with `DXFLoader.loadContours` |
| **DWG** (AutoCAD native, 2D vector) | ✅ R2000 to R2018 (R14 for simple entities) | no | OCCTSwiftIO | [SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG) (MIT, in process, no tool to install) → SwiftDXF entity model |

The MeshIO rows are the mesh-only path, with no OCCT. OCCTSwiftIO also reads STL and OBJ into OCCT
`Shape`s (`ShapeLoader`), and exports `Shape`s as OBJ, PLY, glTF and GLB meshes
([Export](#export-occtswiftio)).

## Notes

### Mesh formats (MeshIO)

- **Welding.** Readers weld coincident vertices (`weldEpsilon`, default `1e-4`) so connectivity is
  restored in formats that split vertices at seams.
- **PMX / `.x`** are *source* formats (game / 3D-model assets), read-only. They carry no canonical
  units; consumers may need to scale.
- **glTF / GLB read** delegates the hard decode (JSON/GLB container, buffers, external `.bin`,
  accessors) to SwiftGLTF; node transforms are baked. **Write** is a native minimal glTF/GLB
  (positions + indices → one buffer; `.glb` binary or self-contained `.gltf` with a base64 buffer).
- **3MF** reads ThreeMF's flattened model (build items expanded into placed mesh instances) and writes
  a single-object package.

### CAD & vector (OCCTSwiftIO)

- **STEP / IGES / BREP** load to OCCT `Shape`s with per-shape colors and AP242 dimensions / datums.
- **JWW** is a 2D vector drawing, not a mesh or solid. It loads to a single **compound `Shape` of OCCT
  edges** at **full size**: each element is multiplied by its layer group's scale, so a part drawn
  at 1:80 comes in at its real size. It is read as `DrawingLoader` reads it, through SwiftJWW's DXF
  writer, and shares the DXF edge step: lines → line edges, arcs/circles → circular-arc edges (the
  JWW *tilt* axis is honoured), ellipses → line and circular-arc edges fitted within a tolerance,
  as for a DXF, points → vertices, in the `Z = 0` plane. Block inserts are expanded. **Text** has no edges, nor does a dimension written as
  a `DIMENSION`; the lines of one that is not (a value nothing explains, or a record from a file
  older than version 4.20) stay lines. A dimension that is a `DIMENSION` is counted in a `.noEdges`
  warning, as text is.
- **DXF and DWG** load to one compound of curve edges, as JWW does. Block references are expanded, so
  the geometry in a block is in the compound. For all three, `ShapeLoadResult.warnings` carries what
  was left out (the same `DrawingWarning`s `DrawingLoader` gives) and, in a `.noEdges` warning for
  each type and layer, what was read and has no edges: text, dimensions, hatches, leaders, tolerance
  frames, solid fills, wipeouts and 3D faces. Geometry with no size (a zero-length line, a
  zero-radius circle) is `.degenerate`, and geometry OCCT will not build is `.notBuilt`. A DWG's
  limits are in
  [DWGLoader](reference/DWGLoader.md#limits-that-matter-to-a-caller).

## Export (OCCTSwiftIO)

`ExportManager.export(shapes:format:to:)` writes OCCT `Shape`s to **OBJ / PLY / STEP / BREP / glTF /
GLB**. For pure-mesh output without the kernel, prefer `MeshIO.write`.
