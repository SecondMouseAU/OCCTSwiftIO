---
title: MeshIO
parent: API Reference
---

# MeshIO

`MeshIO` is the pure-Swift mesh file I/O entry point — **no OCCT**. It reads STL / OBJ / PLY / glTF /
GLB / 3MF / PMX / `.x` and writes everything except the two source-only formats (PMX, `.x`), all
through the neutral [`Mesh`](Mesh.md) value type. The companion `MeshFormat` enum and `MeshError` type
live here too.

## Topics

- [`MeshError`](#mesherror) · [`MeshFormat`](#meshformat) · [`MeshIO.readableExtensions`](#meshioreadableextensions) · [`MeshIO.load(contentsOf:weldEpsilon:)`](#meshioloadcontentsofweldepsilon) · [`MeshIO.write(_:to:format:asciiSTL:)`](#meshiowritetoformatasciistl)

---

## `MeshError`

```swift
public enum MeshError: Error, Equatable, Sendable {
    case empty
    case notRecognized
    case unknownExtension(String)
    case unsupported(String)
}
```

- `empty` — input data was empty.
- `notRecognized` — bytes didn't parse into a usable mesh.
- `unknownExtension` — the file extension maps to no `MeshFormat`.
- `unsupported` — operation not supported (e.g. writing PMX / `.x`, or big-endian PLY).

---

## `MeshFormat`

The 3D mesh formats MeshIO handles. Mesh-only — CAD B-Rep and 2D vector formats live in OCCTSwiftIO.

```swift
public enum MeshFormat: String, Sendable, CaseIterable {
    case stl, obj, ply, pmx, x      // x = DirectX .x
    case threeMF = "3mf"
    case gltf, glb

    public init?(fileExtension ext: String)
    public var canRead: Bool   { true }
    public var canWrite: Bool  { self != .pmx && self != .x }
}
```

- `init?(fileExtension:)` — maps a case-insensitive extension (`stl`/`obj`/`ply`/`pmx`/`x`/`3mf`/`gltf`/`glb`)
  to a case, `nil` otherwise.
- `canWrite` — `false` for `pmx` and `x` (source-only formats); `true` for the rest.

---

## `MeshIO.readableExtensions`

```swift
public static var readableExtensions: [String] { get }
```

- **Returns:** all readable format extensions: `["stl", "obj", "ply", "pmx", "x", "3mf", "gltf", "glb"]`.

---

## `MeshIO.load(contentsOf:weldEpsilon:)`

Loads a mesh file, choosing the reader by extension. glTF / GLB load from the URL so external `.bin`
buffers resolve relative to it; other formats read from in-memory `Data`.

```swift
public static func load(contentsOf url: URL, weldEpsilon: Float = 1e-4) throws -> Mesh
```

- **Parameters:** `url` — the mesh file; `weldEpsilon` — vertex-weld grid size (default `1e-4`; pass
  `0` to skip welding).
- **Returns:** a welded `Mesh`.
- **Throws:** `MeshError.unknownExtension` for an unrecognised extension; `.empty` / `.notRecognized`
  for unparseable data; `.unsupported` for unsupported variants. PMX / `.x` are read via the SwiftPMX /
  SwiftX packages. For PMX, the returned `Mesh.submeshes` carries the file's per-material index ranges
  (see [`Submesh`](Mesh.md#submesh)) — empty for every other format, including `.x`.
- **Example:**
  ```swift
  let mesh = try MeshIO.load(contentsOf: url)
  print(mesh.vertexCount, mesh.triangleCount)
  ```

---

## `MeshIO.write(_:to:format:asciiSTL:)`

Writes a mesh, choosing the writer by `format` (or by the file extension when `format` is `nil`).

```swift
public static func write(
    _ mesh: Mesh,
    to url: URL,
    format: MeshFormat? = nil,
    asciiSTL: Bool = false
) throws
```

- **Parameters:**
  - `mesh` — the mesh to write.
  - `url` — destination file.
  - `format` — explicit format; if `nil`, inferred from `url.pathExtension`.
  - `asciiSTL` — write ASCII STL instead of binary (STL only; default `false`).
- **Throws:** `MeshError.unsupported` when the resolved format is `pmx` / `x` / `nil`.
- **Example:**
  ```swift
  try MeshIO.write(mesh, to: outURL)                            // by extension
  try MeshIO.write(mesh, to: stlURL, format: .stl, asciiSTL: true)
  ```
