---
title: GraphExport (ML)
parent: API Reference
---

# GraphExport (ML export)

OCCTSwiftIO adds a consumption-side ML repacking layer as an extension on `OCCTSwift.TopologyGraph`:
flat vertex positions, per-edge boundary/manifold flags, and COO-format sparse adjacency for face /
edge / vertex incidence. (Hoisted from OCCTSwift per OCCTSwiftIO#1 — pure batch / headless, fitting
this package's charter.)

## Topics

- [`TopologyGraph.GraphExport`](#topologygraphgraphexport) · [`TopologyGraph.exportForML()`](#topologygraphexportforml) · [`TopologyGraph.exportJSON()`](#topologygraphexportjson)

---

## `TopologyGraph.GraphExport`

Graph data in ML-friendly form: flat arrays plus COO sparse adjacency.

```swift
public struct GraphExport: Sendable {
    /// Nx3 vertex positions (each inner array is [x, y, z]).
    public let vertexPositions: [[Double]]
    /// Per-edge boundary flag.
    public let edgeBoundaryFlags: [Bool]
    /// Per-edge manifold flag.
    public let edgeManifoldFlags: [Bool]
    /// Per-face list of adjacent face indices.
    public let faceAdjacentFaces: [[Int]]
    /// Face-to-edge incidence in COO format.
    public let faceToEdge: (sources: [Int], targets: [Int])
    /// Edge-to-vertex incidence in COO format.
    public let edgeToVertex: (sources: [Int], targets: [Int])
    /// Face-to-face adjacency in COO format.
    public let faceToFace: (sources: [Int], targets: [Int])
}
```

Each COO pair is two parallel arrays: `sources[i]` → `targets[i]` is one edge of the incidence graph.

---

## `TopologyGraph.exportForML()`

Builds a `GraphExport` from the graph (vertex positions, per-edge flags, face adjacency, and the three
COO incidence relations).

```swift
public func exportForML() -> GraphExport
```

- **Returns:** a `GraphExport` value.
- **Example:**
  ```swift
  let export = shape.topologyGraph().exportForML()
  let (src, tgt) = export.faceToFace
  print(export.vertexPositions.count, "vertices,", src.count, "face-face edges")
  ```

---

## `TopologyGraph.exportJSON()`

Serializes the export as JSON for ML pipelines. The tuple-typed COO pairs are flattened into parallel
`*Sources` / `*Targets` arrays in the JSON.

```swift
public func exportJSON() -> Data?
```

- **Returns:** encoded JSON `Data`, or `nil` if encoding fails.
- **Example:**
  ```swift
  if let data = shape.topologyGraph().exportJSON() {
      try data.write(to: graphURL)
  }
  ```
