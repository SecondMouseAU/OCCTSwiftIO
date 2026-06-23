---
title: Reading & writing meshes
parent: Cookbook
nav_order: 3
---

# Reading & writing meshes

`MeshIO` is pure Swift — **no OCCT**. It reads STL / OBJ / PLY / glTF / GLB / 3MF / PMX / `.x` and
writes everything except the two source-only formats (PMX, `.x`), all through the neutral `Mesh`
value type.

## Load and inspect

```swift
import MeshIO

let mesh = try MeshIO.load(contentsOf: url)        // reader chosen by extension
print(mesh.vertexCount, mesh.triangleCount)
if let (lo, hi) = mesh.bounds { print("bbox:", lo, hi) }

let (a, b, c) = mesh.trianglePositions(0)          // first triangle's three corner positions
```

`MeshIO.load` welds coincident vertices on read (default `weldEpsilon: 1e-4`, restoring connectivity
for formats that split vertices at seams). Pass `weldEpsilon: 0` to skip welding:

```swift
let raw = try MeshIO.load(contentsOf: objURL, weldEpsilon: 0)
```

glTF / GLB load from the `URL` (so external `.bin` buffers resolve relative to it); all other formats
read from in-memory `Data`.

## Write

```swift
try MeshIO.write(mesh, to: outURL)                       // writer inferred from extension
try MeshIO.write(mesh, to: stlURL, format: .stl, asciiSTL: true)   // ASCII STL (default is binary)
```

`asciiSTL` only affects STL output. Writing PMX or `.x` throws `MeshError.unsupported` — they are
read-only source formats. You can check up front:

```swift
if let fmt = MeshFormat(fileExtension: ext), fmt.canWrite {
    try MeshIO.write(mesh, to: outURL, format: fmt)
}
print(MeshIO.readableExtensions)   // ["stl", "obj", "ply", "pmx", "x", "3mf", "gltf", "glb"]
```

## The Mesh value type

```swift
public struct Mesh: Equatable, Sendable {
    public var positions: [SIMD3<Float>]
    public var indices: [UInt32]
}
```

Build one directly, or from a triangle soup:

```swift
let welded = Mesh.welded(triangleSoup, epsilon: 1e-4)   // merge coincident corners
let soup   = Mesh.indexedSoup(triangleSoup)             // each corner its own vertex
```

## Calling the format readers directly

The per-format types are public if you have the bytes in hand and want to skip extension dispatch:

```swift
let m1 = try STL.read(data: stlData)
let m2 = try OBJ.read(data: objData)
let m3 = try PLY.read(data: plyData)

let stlBytes  = STL.binaryData(mesh)
let stlAscii  = STL.asciiString(mesh)
let objString = OBJ.string(mesh)
let plyString = PLY.string(mesh)
```
