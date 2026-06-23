---
title: ML graph export
parent: Cookbook
nav_order: 6
---

# ML graph export

OCCTSwiftIO adds a consumption-side ML repacking layer on top of OCCTSwift's `TopologyGraph`: flat
vertex positions, per-edge boundary/manifold flags, and COO-format sparse adjacency for face / edge /
vertex incidence. It is an extension on `OCCTSwift.TopologyGraph`, so you call it on any graph you
already have.

## Export to a struct

```swift
import OCCTSwift
import OCCTSwiftIO

let graph = shape.topologyGraph()       // an OCCTSwift TopologyGraph
let export = graph.exportForML()

print(export.vertexPositions.count)     // Nx3, each [x, y, z]
print(export.edgeBoundaryFlags)         // Bool per edge
print(export.edgeManifoldFlags)         // Bool per edge
print(export.faceAdjacentFaces)         // per-face list of adjacent face indices

// COO sparse adjacency (parallel sources/targets arrays):
let (fe_s, fe_t) = export.faceToEdge
let (ev_s, ev_t) = export.edgeToVertex
let (ff_s, ff_t) = export.faceToFace
```

## The GraphExport shape

```swift
public struct GraphExport: Sendable {
    public let vertexPositions: [[Double]]
    public let edgeBoundaryFlags: [Bool]
    public let edgeManifoldFlags: [Bool]
    public let faceAdjacentFaces: [[Int]]
    public let faceToEdge:   (sources: [Int], targets: [Int])
    public let edgeToVertex: (sources: [Int], targets: [Int])
    public let faceToFace:   (sources: [Int], targets: [Int])
}
```

## Export to JSON

For pipelines that ingest JSON (the tuple-typed COO pairs are flattened into parallel `*Sources` /
`*Targets` arrays):

```swift
if let data = graph.exportJSON() {
    try data.write(to: graphURL)
}
```

`exportJSON()` returns `Data?` — `nil` only if JSON encoding fails.
