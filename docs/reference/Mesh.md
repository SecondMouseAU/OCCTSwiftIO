---
title: Mesh
parent: API Reference
---

# Mesh

`Mesh` is the neutral currency of MeshIO: a welded, indexed triangle mesh. Positions are unique and
`indices` holds three vertex indices per triangle. It is a pure `Equatable`, `Sendable` value type with
no OCCT dependency.

## Topics

- [Properties](#properties) · [`init(positions:indices:)`](#initpositionsindices) · [`triangle(_:)` / `trianglePositions(_:)`](#triangle_--trianglepositions_) · [`bounds`](#bounds) · [`Mesh.welded(_:epsilon:)`](#meshweldedepsilon) · [`Mesh.indexedSoup(_:)`](#meshindexedsoup)

---

## Properties

```swift
public struct Mesh: Equatable, Sendable {
    public var positions: [SIMD3<Float>]
    public var indices: [UInt32]

    public var vertexCount: Int   { positions.count }
    public var triangleCount: Int { indices.count / 3 }
}
```

---

## `init(positions:indices:)`

```swift
public init(positions: [SIMD3<Float>] = [], indices: [UInt32] = [])
```

- **Parameters:** `positions` — unique vertex positions; `indices` — three vertex indices per triangle.
  Both default to empty.

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
