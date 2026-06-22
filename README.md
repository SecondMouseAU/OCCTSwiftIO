# OCCTSwiftIO

[![License](https://img.shields.io/badge/license-LGPL--2.1-blue)](LICENSE)
[![Docs](https://img.shields.io/badge/docs-page-2ea44f)](https://secondmouseau.github.io/OCCTSwiftIO/)

📖 **Documentation:** <https://secondmouseau.github.io/OCCTSwiftIO/>

Headless file I/O for the [OCCTSwift](https://github.com/SecondMouseAU/OCCTSwift) ecosystem. **No
Viewport dependency** — safe for CLIs, batch pipelines, and server-side workflows. The package ships
**two products** so consumers take only what they need:

| Product | Depends on OCCT? | What it's for |
|---|---|---|
| **`MeshIO`** | **No** (pure Swift) | 3D **mesh** formats → a neutral `Mesh` (positions + indices). |
| **`OCCTSwiftIO`** | Yes | **CAD B-Rep** load/export as OCCT `Shape`s + **JWW** (2D vector) load. |

The split lets OCCT-free consumers (e.g. a raw-mesh pipeline) read meshes without pulling in the 1.3 GB
kernel; `OCCTSwiftIO` builds on top of `MeshIO` and adds the kernel-backed formats.

## Format coverage

| Format | Read | Write | Product |
|---|---|---|---|
| STL (ascii+binary) | ✅ | ✅ | MeshIO |
| OBJ | ✅ | ✅ | MeshIO |
| PLY (ascii+binary) | ✅ | ✅ | MeshIO |
| glTF / GLB | ✅ | ✅ | MeshIO |
| 3MF | ✅ | ✅ | MeshIO |
| PMX (MikuMikuDance) | ✅ | — | MeshIO |
| DirectX `.x` | ✅ | — | MeshIO |
| STEP / IGES / BREP | ✅ | ✅* | OCCTSwiftIO |
| JWW (Jw_cad, 2D vector) | ✅ | — | OCCTSwiftIO |

<sub>*OCCTSwiftIO `ExportManager` exports OCCT `Shape`s to STEP / BREP / OBJ / PLY / glTF / GLB.</sub>

## Install

```swift
dependencies: [
    .package(url: "https://github.com/SecondMouseAU/OCCTSwiftIO.git", from: "1.4.0"),
],
// then add the product(s) you need:
.target(name: "YourTarget", dependencies: [
    .product(name: "MeshIO", package: "OCCTSwiftIO"),        // mesh, no OCCT
    .product(name: "OCCTSwiftIO", package: "OCCTSwiftIO"),   // CAD + JWW (pulls OCCT)
]),
```

## MeshIO — pure-Swift mesh I/O

```swift
import MeshIO

let mesh = try MeshIO.load(contentsOf: url)        // .stl/.obj/.ply/.gltf/.glb/.3mf/.pmx/.x
print(mesh.vertexCount, mesh.triangleCount, mesh.bounds as Any)

try MeshIO.write(mesh, to: outURL)                 // format inferred from extension
try MeshIO.write(mesh, to: stlURL, format: .stl, asciiSTL: true)
```

`Mesh` is a value type (`positions: [SIMD3<Float>]`, `indices: [UInt32]`). PMX/`.x` are read via the
standalone [SwiftPMX](https://github.com/SecondMouseAU/SwiftPMX) / [SwiftX](https://github.com/SecondMouseAU/SwiftX)
packages; 3MF via [ThreeMF](https://github.com/tomasf/ThreeMF); glTF read via
[SwiftGLTF](https://github.com/schwa/SwiftGLTF) (write is native).

## OCCTSwiftIO — CAD + JWW

```swift
import OCCTSwift
import OCCTSwiftIO

// STEP / IGES / BREP → shapes + colors + AP242 metadata.
let result = try await ShapeLoader.load(from: stepURL, format: .step)

// JWW (Jw_cad 2D drawing) → a compound of OCCT edges (lines, arcs/circles, points).
let drawing = try await ShapeLoader.load(from: jwwURL, format: .jww)

// Export shapes to STEP / BREP / OBJ / PLY / glTF / GLB.
try await ExportManager.export(shapes: result.shapes, format: .glb, to: outURL)
```

For body-producing loaders (CPU mesh + pick data for AIS), use
[OCCTSwiftTools](https://github.com/SecondMouseAU/OCCTSwiftTools), which wraps this package.

## Architecture position

```
OCCTSwiftTools     (bridge — Shape ↔ ViewportBody)
       ↑
OCCTSwiftIO        ← this repo (headless file I/O)        MeshIO  ← pure-Swift mesh (no OCCT)
       ↑                                                     ↑
OCCTSwift          (B-Rep kernel)              SwiftPMX / SwiftX / ThreeMF / SwiftGLTF / SwiftJWW
```

**Hard rule: no Viewport dependency in this package.** Produce `ViewportBody`s in OCCTSwiftTools.

## License

LGPL-2.1 (inherited from OCCTSwift / OCCT). The mesh-format reader packages carry their own permissive
licenses (MIT / BSD-3).
