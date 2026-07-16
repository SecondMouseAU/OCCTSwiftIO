---
title: Mesh
parent: API Reference
---

# Mesh

`Mesh` is the neutral currency of MeshIO: a welded, indexed triangle mesh. Positions are unique and
`indices` holds three vertex indices per triangle. It is a pure `Equatable`, `Sendable` value type with
no OCCT dependency.

## Topics

- [Properties](#properties) · [`Submesh`](#submesh) · [`init(positions:indices:submeshes:)`](#initpositionsindicessubmeshes) · [`triangle(_:)` / `trianglePositions(_:)`](#triangle_--trianglepositions_) · [`bounds`](#bounds) · [`Mesh.welded(_:epsilon:)`](#meshweldedepsilon) · [`Mesh.indexedSoup(_:)`](#meshindexedsoup)

---

## Properties

```swift
public struct Mesh: Equatable, Sendable {
    public var positions: [SIMD3<Float>]
    public var indices: [UInt32]
    public var submeshes: [Submesh]

    public var vertexCount: Int   { positions.count }
    public var triangleCount: Int { indices.count / 3 }
}
```

`submeshes` is empty for formats/files with no per-material grouping — currently populated only for
PMX (see [`Submesh`](#submesh)).

---

## `Submesh`

One contiguous run of `Mesh.indices` belonging to a single source-format material — the source
format's own segmentation of the face buffer, so a single part can be isolated from a whole-model mesh.

```swift
public struct Submesh: Equatable, Sendable {
    public var indexOffset: Int      // start of this run in Mesh.indices
    public var indexCount: Int       // length of this run (always a multiple of 3)
    public var materialIndex: Int    // index into the source file's material list (0-based, file order)
}
```

- **Example:**
  ```swift
  let mesh = try MeshIO.load(contentsOf: pmxURL)
  for sub in mesh.submeshes {                        // isolate one material's triangles
      let range = sub.indexOffset ..< sub.indexOffset + sub.indexCount
      print("material \(sub.materialIndex): \(sub.indexCount / 3) triangles")
  }
  ```

---

## `init(positions:indices:submeshes:)`

```swift
public init(positions: [SIMD3<Float>] = [], indices: [UInt32] = [], submeshes: [Submesh] = [])
```

- **Parameters:** `positions` — unique vertex positions; `indices` — three vertex indices per triangle;
  `submeshes` — per-material index ranges. All default to empty.

---

## `triangle(_:)` / `trianglePositions(_:)`

```swift
public func triangle(_ t: Int) -> (UInt32, UInt32, UInt32)
public func trianglePositions(_ t: Int) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
```

- **Returns:** `triangle` returns the three vertex *indices* of triangle `t`; `trianglePositions`
  returns the three corner *positions*.
- **Example:**
  ```swift
  for t in 0..<mesh.triangleCount {
      let (a, b, c) = mesh.trianglePositions(t)
      // ... use the three corner positions
  }
  ```

---

## `bounds`

```swift
public var bounds: (min: SIMD3<Float>, max: SIMD3<Float>)? { get }
```

- **Returns:** the axis-aligned bounding box as `(min, max)`, or `nil` for an empty mesh.

---

## `Mesh.welded(_:epsilon:)`

Merges coincident vertices by quantizing positions to a grid of size `epsilon` — restores connectivity
in formats that split vertices at seams.

```swift
public static func welded(_ soup: [SIMD3<Float>], epsilon: Float) -> Mesh
```

- **Parameters:** `soup` — a flat triangle soup (3 positions per triangle); `epsilon` — the weld grid
  size.
- **Returns:** an indexed `Mesh` with coincident corners merged.
- **Example:**
  ```swift
  let mesh = Mesh.welded(triangleSoup, epsilon: 1e-4)
  ```

---

## `Mesh.indexedSoup(_:)`

Indexes a triangle soup *without* welding — each corner becomes its own vertex.

```swift
public static func indexedSoup(_ soup: [SIMD3<Float>]) -> Mesh
```

- **Parameters:** `soup` — a flat triangle soup.
- **Returns:** a `Mesh` with one vertex per input corner.
