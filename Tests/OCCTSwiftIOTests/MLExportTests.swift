// MLExportTests.swift
// OCCTSwiftIOTests
//
// Lifted from OCCTSwift/Tests/OCCTSwiftTests/ShapeTests.swift, suite
// "BRepGraph ML Export". The third test was renamed `t_exportJSON`
// to avoid shadowing the API method per local CLAUDE.md convention.
// "BRepGraph UV Grid" stays in OCCTSwift, see MLExport.swift header.

import Foundation
import OCCTSwift
import Testing

@testable import OCCTSwiftIO

@Suite("BRepGraph ML Export")
struct BRepGraphMLExportTests {
    @Test func exportBoxGraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let exported = graph.exportForML()
                #expect(exported.vertexPositions.count == 8)
                #expect(exported.edgeBoundaryFlags.count == 12)
                #expect(exported.edgeManifoldFlags.count == 12)
                #expect(exported.faceAdjacentFaces.count == 6)
                for pos in exported.vertexPositions {
                    #expect(pos.count == 3)
                }
                for i in 0..<12 {
                    #expect(exported.edgeManifoldFlags[i])
                    #expect(!exported.edgeBoundaryFlags[i])
                }
                for adj in exported.faceAdjacentFaces {
                    #expect(adj.count == 4)
                }
            }
        }
    }

    @Test func exportCOOFormat() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let exported = graph.exportForML()
                #expect(exported.edgeToVertex.sources.count == exported.edgeToVertex.targets.count)
                #expect(exported.edgeToVertex.sources.count == 24)
                #expect(exported.faceToEdge.sources.count == exported.faceToEdge.targets.count)
                #expect(exported.faceToEdge.sources.count > 0)
                #expect(exported.faceToFace.sources.count == exported.faceToFace.targets.count)
                #expect(exported.faceToFace.sources.count == 24)
            }
        }
    }

    @Test func t_exportJSON() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let json = graph.exportJSON()
                #expect(json != nil)
                if let json {
                    #expect(json.count > 0)
                    let obj = try? JSONSerialization.jsonObject(with: json)
                    #expect(obj != nil)
                    if let dict = obj as? [String: Any] {
                        #expect(dict["vertexPositions"] != nil)
                        #expect(dict["edgeBoundaryFlags"] != nil)
                        #expect(dict["faceToFaceSources"] != nil)
                    }
                }
            }
        }
    }

    @Test func exportSphere() {
        if let sphere = Shape.sphere(radius: 5) {
            if let graph = BRepGraph(shape: sphere) {
                let exported = graph.exportForML()
                #expect(exported.vertexPositions.count == graph.vertexCount)
                #expect(exported.edgeBoundaryFlags.count == graph.edgeCount)
                #expect(exported.faceAdjacentFaces.count == graph.faceCount)
            }
        }
    }
}
