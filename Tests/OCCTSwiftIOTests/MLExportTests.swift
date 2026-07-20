// MLExportTests.swift
// OCCTSwiftIOTests
//
// Lifted from OCCTSwift/Tests/OCCTSwiftTests/ShapeTests.swift, suite
// "BRepGraph ML Export". The third test was renamed `t_exportJSON`
// to avoid shadowing the API method per local CLAUDE.md convention.
// "BRepGraph UV Grid" stays in OCCTSwift — see MLExport.swift header.

import Testing
import Foundation
import OCCTSwift
@testable import OCCTSwiftIO

@Suite("BRepGraph ML Export")
struct BRepGraphMLExportTests {
    @Test func exportBoxGraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let export_ = graph.exportForML()
                #expect(export_.vertexPositions.count == 8)
                #expect(export_.edgeBoundaryFlags.count == 12)
                #expect(export_.edgeManifoldFlags.count == 12)
                #expect(export_.faceAdjacentFaces.count == 6)
                for pos in export_.vertexPositions {
                    #expect(pos.count == 3)
                }
                for i in 0..<12 {
                    #expect(export_.edgeManifoldFlags[i])
                    #expect(!export_.edgeBoundaryFlags[i])
                }
                for adj in export_.faceAdjacentFaces {
                    #expect(adj.count == 4)
                }
            }
        }
    }

    @Test func exportCOOFormat() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let export_ = graph.exportForML()
                #expect(export_.edgeToVertex.sources.count == export_.edgeToVertex.targets.count)
                #expect(export_.edgeToVertex.sources.count == 24)
                #expect(export_.faceToEdge.sources.count == export_.faceToEdge.targets.count)
                #expect(export_.faceToEdge.sources.count > 0)
                #expect(export_.faceToFace.sources.count == export_.faceToFace.targets.count)
                #expect(export_.faceToFace.sources.count == 24)
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
                let export_ = graph.exportForML()
                #expect(export_.vertexPositions.count == graph.vertexCount)
                #expect(export_.edgeBoundaryFlags.count == graph.edgeCount)
                #expect(export_.faceAdjacentFaces.count == graph.faceCount)
            }
        }
    }
}
