---
title: Formats
nav_order: 4
---

# Formats

| Format | Read | Write | Product | Backend |
|---|---|---|---|---|
| **STL** (ascii + binary) | ✅ | ✅ | MeshIO | native |
| **OBJ** | ✅ | ✅ | MeshIO | native |
| **PLY** (ascii + binary-LE) | ✅ | ✅ | MeshIO | native |
| **glTF / GLB** | ✅ | ✅ | MeshIO | [SwiftGLTF](https://github.com/schwa/SwiftGLTF) (read) + native (write) |
| **3MF** | ✅ | ✅ | MeshIO | [ThreeMF](https://github.com/tomasf/ThreeMF) |
| **PMX** (MikuMikuDance) | ✅ | — | MeshIO | [SwiftPMX](https://github.com/SecondMouseAU/SwiftPMX) |
| **DirectX `.x`** | ✅ | — | MeshIO | [SwiftX](https://github.com/SecondMouseAU/SwiftX) |
| **STEP** / **IGES** / **BREP** | ✅ | ✅ | OCCTSwiftIO | OCCT |
| **JWW** (Jw_cad, 2D vector) | ✅ | — | OCCTSwiftIO | [SwiftJWW](https://github.com/SecondMouseAU/SwiftJWW) → OCCT edges |

## Notes

### Mesh formats (MeshIO)

- **Welding.** Readers weld coincident vertices (`weldEpsilon`, default `1e-4`) so connectivity is
  restored in formats that split vertices at seams.
- **PMX / `.x`** are *source* formats (game / 3D-model assets) — read-only. They carry no canonical
  units; consumers may need to scale.
- **glTF / GLB read** delegates the hard decode (JSON/GLB container, buffers, external `.bin`,
  accessors) to SwiftGLTF; node transforms are baked. **Write** is a native minimal glTF/GLB
  (positions + indices → one buffer; `.glb` binary or self-contained `.gltf` with a base64 buffer).
- **3MF** reads ThreeMF's flattened model (build items expanded into placed mesh instances) and writes
  a single-object package.

### CAD & vector (OCCTSwiftIO)

- **STEP / IGES / BREP** load to OCCT `Shape`s with per-shape colors and AP242 dimensions / datums.
- **JWW** is a 2D vector drawing, not a mesh or solid. It loads to a single **compound `Shape` of OCCT
  edges**: lines → line edges, arcs/circles → circular-arc edges (the JWW *tilt* axis is honoured),
  ellipses → polyline approximations, points → vertices. Coordinates lie in the `Z = 0` plane.
  **Text** is not converted to geometry (it would need font outlines), and **block inserts** are not
  yet expanded.

## Export (OCCTSwiftIO)

`ExportManager.export(shapes:format:to:)` writes OCCT `Shape`s to **OBJ / PLY / STEP / BREP / glTF /
GLB**. For pure-mesh output without the kernel, prefer `MeshIO.write`.
