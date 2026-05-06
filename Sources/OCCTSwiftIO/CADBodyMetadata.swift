// CADBodyMetadata.swift
// OCCTSwiftIO
//
// Pure-data record produced by the bridge layer (OCCTSwiftTools) for sub-body
// selection (face / edge / vertex). Lives here so the type itself doesn't pull
// in OCCTSwiftViewport — the bridge consumes it, doesn't need Viewport types
// to express it.

import simd
import OCCTSwift

/// Metadata extracted from OCCTSwift for sub-body selection (face, edge, vertex).
///
/// `faceIndices` is parallel to a triangulated mesh's index list (one entry
/// per triangle, value = source-face index). `edgePolylines` and `vertices`
/// give the picking layer the data it needs to round-trip a GPU pick result
/// back to a `TopoDS_Edge` / `TopoDS_Vertex` via `shape.edge(at:)` /
/// `shape.vertex(at:)`.
public struct CADBodyMetadata: Sendable {
    /// Per-triangle source-face index (parallel to the mesh's triangle list).
    public let faceIndices: [Int32]

    /// Edge polylines tagged with their source-edge index.
    public let edgePolylines: [(edgeIndex: Int, points: [SIMD3<Float>])]

    /// Source-shape vertex positions, indexed parallel to `shape.vertices()`.
    public let vertices: [SIMD3<Float>]

    /// Optional per-face area + per-edge length report. Populated only when
    /// the bridge call passes `includeMeasurements: true`. Used by AIS' dimension
    /// widget to label picked faces/edges with their scalar measurement.
    public let measurements: ShapeMeasurements?

    public init(
        faceIndices: [Int32],
        edgePolylines: [(edgeIndex: Int, points: [SIMD3<Float>])],
        vertices: [SIMD3<Float>],
        measurements: ShapeMeasurements? = nil
    ) {
        self.faceIndices = faceIndices
        self.edgePolylines = edgePolylines
        self.vertices = vertices
        self.measurements = measurements
    }
}
