---
title: Mesh format readers
parent: API Reference
---

# Mesh format readers

The native mesh-format types (`STL`, `OBJ`, `PLY`) are public enums you can call directly when you
already have the bytes and want to skip extension dispatch. The glTF and 3MF paths are handled by
internal `MeshIO` adapters over SwiftGLTF / ThreeMF — reach them through
[`MeshIO.load` / `MeshIO.write`](MeshIO.md). All are pure Swift, no OCCT.

## Topics

- [STL](#stl) · [OBJ](#obj) · [PLY](#ply) · [glTF / GLB](#gltf--glb) · [3MF](#3mf)

---

## STL

Native STL reader/writer (ASCII + binary). The reader auto-detects ASCII vs binary by layout.

```swift
public enum STL {
    public static func read(data: Data, weldEpsilon: Float = 1e-4) throws -> Mesh
    public static func binaryData(_ mesh: Mesh) -> Data
    public static func asciiString(_ mesh: Mesh, name: String = "mesh") -> String
}
```

- `read` welds vertices on import (STL splits all triangles). Throws `MeshError.empty` /
  `.notRecognized`.
- `binaryData` writes binary STL; `asciiString` writes ASCII with an optional solid `name`.
- **Example:**
  ```swift
  let mesh = try STL.read(data: try Data(contentsOf: url))
  let bytes = STL.binaryData(mesh)
  ```

---

## OBJ

Native Wavefront OBJ reader/writer — geometry only (`v` + `f`). Faces of any vertex-ref form
(`v`, `v/vt`, `v/vt/vn`, `v//vn`, negative-relative indices) are fan-triangulated.

```swift
public enum OBJ {
    public static func read(data: Data, weldEpsilon: Float = 1e-4) throws -> Mesh
    public static func string(_ mesh: Mesh) -> String
}
```

- `read` throws `MeshError.empty` / `.notRecognized`; welds when `weldEpsilon > 0`.
- `string` writes an OBJ document (1-based `v` / `f`).

---

## PLY

Native PLY reader/writer. Reads ASCII and binary-little-endian PLY (the `vertex` element's x/y/z and
the `face` element's index lists, fan-triangulated). Writes ASCII.

```swift
public enum PLY {
    public static func read(data: Data, weldEpsilon: Float = 1e-4) throws -> Mesh
    public static func string(_ mesh: Mesh) -> String
}
```

- `read` throws `MeshError.unsupported("PLY big-endian")` for big-endian binary; `.empty` /
  `.notRecognized` otherwise.
- `string` writes an ASCII PLY document.

---

## glTF / GLB

Handled by `MeshIO`'s internal SwiftGLTF adapter — call via `MeshIO.load` / `MeshIO.write`.

- **Read** delegates the hard decode (JSON/GLB container, buffers, external `.bin`, accessors) to
  SwiftGLTF; the adapter walks the scene graph, decodes POSITION + index accessors, and bakes node
  transforms. Triangle primitives only.
- **Write** is native and minimal: positions (float32 VEC3) + indices (uint32 SCALAR) packed into one
  buffer. `.gltf` embeds the buffer as a base64 data URI (self-contained); `.glb` writes the binary
  container (12-byte header + JSON chunk + BIN chunk).

```swift
let mesh = try MeshIO.load(contentsOf: gltfURL)   // resolves external .bin relative to the URL
try MeshIO.write(mesh, to: glbURL, format: .glb)
```

---

## 3MF

Handled by `MeshIO`'s internal ThreeMF adapter — call via `MeshIO.load` / `MeshIO.write`.

- **Read** uses ThreeMF's flattened `LoadedModel` (build items expanded into placed mesh instances with
  accumulated transforms), so multi-object / instanced models are positioned correctly.
- **Write** emits a single-object 3MF package.

```swift
let mesh = try MeshIO.load(contentsOf: threeMFURL)
try MeshIO.write(mesh, to: outURL, format: .threeMF)
```
