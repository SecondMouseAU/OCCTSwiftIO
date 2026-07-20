// MLExport.swift
// OCCTSwiftIO
//
// Consumption-side ML repacking of `BRepGraph` data: flat vertex
// positions, per-edge boundary/manifold flags, COO-format adjacency for
// face/edge/vertex incidence. Lifted from OCCTSwift per OCCTSwiftIO#1
// (supersedes OCCTSwift#71) — fits this package's headless charter.
//
// `FaceGridSample` / `sampleFaceUVGrid` (and `sampleEdgeCurve`) intentionally
// stay in OCCTSwift: they call `OCCTBRepGraphSampleFaceUVGrid` / `*SampleEdgeCurve`
// on `BRepGraph.handle`, which is `internal` to the OCCTSwift module.
// Lifting them would require widening kernel visibility — out of scope per
// the partial-lift decision recorded on the issue.

import Foundation
import OCCTSwift

extension BRepGraph {

    /// Graph data exported in ML-friendly format with flat arrays and COO sparse adjacency.
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

    /// Export graph in ML-friendly format with flat arrays and COO sparse adjacency.
    public func exportForML() -> GraphExport {
        let nv = vertexCount
        let ne = edgeCount
        let nf = faceCount
        let nce = coedgeCount

        var vertexPositions = [[Double]]()
        vertexPositions.reserveCapacity(nv)
        for i in 0..<nv {
            let p = vertexPoint(i)
            vertexPositions.append([p.x, p.y, p.z])
        }

        var edgeBoundary = [Bool]()
        var edgeManifold = [Bool]()
        edgeBoundary.reserveCapacity(ne)
        edgeManifold.reserveCapacity(ne)
        for i in 0..<ne {
            edgeBoundary.append(isBoundaryEdge(i))
            edgeManifold.append(isManifoldEdge(i))
        }

        var faceAdj = [[Int]]()
        faceAdj.reserveCapacity(nf)
        var f2fSrc = [Int]()
        var f2fTgt = [Int]()
        for i in 0..<nf {
            let adj = adjacentFaces(of: i)
            faceAdj.append(adj)
            for j in adj {
                f2fSrc.append(i)
                f2fTgt.append(j)
            }
        }

        var f2eSrc = [Int]()
        var f2eTgt = [Int]()
        for i in 0..<nce {
            let fIdx = coedgeFace(i)
            let eIdx = coedgeEdge(i)
            f2eSrc.append(fIdx)
            f2eTgt.append(eIdx)
        }

        var e2vSrc = [Int]()
        var e2vTgt = [Int]()
        for i in 0..<ne {
            if let sv = edgeStartVertex(i) {
                e2vSrc.append(i)
                e2vTgt.append(sv)
            }
            if let ev = edgeEndVertex(i) {
                e2vSrc.append(i)
                e2vTgt.append(ev)
            }
        }

        return GraphExport(
            vertexPositions: vertexPositions,
            edgeBoundaryFlags: edgeBoundary,
            edgeManifoldFlags: edgeManifold,
            faceAdjacentFaces: faceAdj,
            faceToEdge: (sources: f2eSrc, targets: f2eTgt),
            edgeToVertex: (sources: e2vSrc, targets: e2vTgt),
            faceToFace: (sources: f2fSrc, targets: f2fTgt)
        )
    }

    private struct CodableGraphExport: Codable {
        let vertexPositions: [[Double]]
        let edgeBoundaryFlags: [Bool]
        let edgeManifoldFlags: [Bool]
        let faceAdjacentFaces: [[Int]]
        let faceToEdgeSources: [Int]
        let faceToEdgeTargets: [Int]
        let edgeToVertexSources: [Int]
        let edgeToVertexTargets: [Int]
        let faceToFaceSources: [Int]
        let faceToFaceTargets: [Int]
    }

    /// Export graph as JSON data for ML pipelines.
    public func exportJSON() -> Data? {
        let export_ = exportForML()
        let codable = CodableGraphExport(
            vertexPositions: export_.vertexPositions,
            edgeBoundaryFlags: export_.edgeBoundaryFlags,
            edgeManifoldFlags: export_.edgeManifoldFlags,
            faceAdjacentFaces: export_.faceAdjacentFaces,
            faceToEdgeSources: export_.faceToEdge.sources,
            faceToEdgeTargets: export_.faceToEdge.targets,
            edgeToVertexSources: export_.edgeToVertex.sources,
            edgeToVertexTargets: export_.edgeToVertex.targets,
            faceToFaceSources: export_.faceToFace.sources,
            faceToFaceTargets: export_.faceToFace.targets
        )
        return try? JSONEncoder().encode(codable)
    }
}
