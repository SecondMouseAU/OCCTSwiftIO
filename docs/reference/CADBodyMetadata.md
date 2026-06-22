---
title: CADBodyMetadata
parent: API Reference
---

# CADBodyMetadata

`CADBodyMetadata` is a pure-data record produced by the bridge layer (OCCTSwiftTools) for sub-body
selection — face / edge / vertex picking. It lives in OCCTSwiftIO so the type itself doesn't pull in
OCCTSwiftViewport: the bridge consumes it, but doesn't need Viewport types to express it.

## Topics

- [`CADBodyMetadata`](#cadbodymetadata-1) · [`CADBodyMetadata.init(faceIndices:edgePolylines:vertices:measurements:)`](#cadbodymetadatainitfaceindicesedgepolylinesverticesmeasurements)

---

## `CADBodyMetadata`

```swift
public struct CADBodyMetadata: Sendable {
    /// Per-triangle source-face index (parallel to the mesh's triangle list).
    public let faceIndices: [Int32]

    /// Edge polylines tagged with their source-edge index.
    public let edgePolylines: [(edgeIndex: Int, points: [SIMD3<Float>])]

    /// Source-shape vertex positions, indexed parallel to `shape.vertices()`.
    public let vertices: [SIMD3<Float>]

    /// Optional per-face area + per-edge length report. Populated only when the
    /// bridge passes `includeMeasurements: true`.
    public let measurements: ShapeMeasurements?
}
```

- `faceIndices` — one entry per triangle of a triangulated mesh, value = source-face index.
- `edgePolylines` — gives the picking layer enough to round-trip a GPU pick back to a `TopoDS_Edge`
  via `shape.edge(at:)`.
- `vertices` — source-shape vertex positions, parallel to `shape.vertices()` for `shape.vertex(at:)`.
- `measurements` — optional `ShapeMeasurements` (from OCCTSwift); populated only when measurements were
  requested. Used by AIS' dimension widget to label picked faces/edges.

---

## `CADBodyMetadata.init(faceIndices:edgePolylines:vertices:measurements:)`

```swift
public init(
    faceIndices: [Int32],
    edgePolylines: [(edgeIndex: Int, points: [SIMD3<Float>])],
    vertices: [SIMD3<Float>],
    measurements: ShapeMeasurements? = nil
)
```

- **Parameters:** the four stored properties above; `measurements` defaults to `nil`.
