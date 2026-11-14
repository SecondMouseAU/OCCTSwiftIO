import Foundation
import OCCTSwift
import Testing
import simd

@testable import OCCTSwiftIO

/// A STEP assembly loads as its leaves, not as its root alongside them (#41).
///
/// The files are written at test time through `Document`, the way a CAD program writes a root
/// product with a child product for each part.
@Suite("STEP assemblies")
struct STEPAssemblyTests {

    private static func tempURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/occtswiftio-assembly-\(UUID().uuidString)-\(name)")
    }

    private static func box(_ size: Double) throws -> Shape {
        try #require(Shape.box(width: size, height: size, depth: size))
    }

    /// The solids in a shape: itself if it is one, else the solids it holds.
    private static func solidCount(_ shape: Shape) -> Int {
        shape.shapeType == .solid ? 1 : shape.subShapes(ofType: .solid).count
    }

    /// The centre of a shape's bounding box.
    ///
    /// The boxes are centred on their origin, so this is where the part was placed.
    private static func centre(of shape: Shape) throws -> SIMD3<Double> {
        let b = try #require(shape.bounds)
        return (b.min + b.max) / 2
    }

    /// A document with an assembly of `parts` boxes, each placed 20 apart along x.
    private static func assembly(parts: Int, in doc: Document) throws -> Int64 {
        let root = doc.newShapeLabel()
        for index in 0..<parts {
            let part = doc.addShape(try box(Double(index + 1)), makeAssembly: false)
            doc.addComponent(
                assemblyLabelId: root, shapeLabelId: part,
                translation: (Double(index) * 20, 0, 0))
        }
        return root
    }

    private static func write(_ doc: Document, _ name: String) throws -> URL {
        doc.updateAssemblies()
        let url = tempURL(name)
        try doc.write(to: url)
        return url
    }

    private static func load(_ url: URL) async throws -> ShapeLoadResult {
        try await ShapeLoader.load(from: url, format: .step)
    }

    @Test("an assembly of three solids loads as three bodies, not four")
    func threeSolidAssembly() async throws {
        let doc = try #require(Document.create())
        _ = try Self.assembly(parts: 3, in: doc)
        let url = try Self.write(doc, "three.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await Self.load(url)
        #expect(result.shapesWithColors.count == 3)
        for (shape, _) in result.shapesWithColors {
            #expect(Self.solidCount(shape) == 1, "each body is one leaf solid, not a grouping")
        }
        // Each part keeps its place: they were put 20 apart along x.
        let centres = try result.shapesWithColors.map { try Self.centre(of: $0.shape).x }.sorted()
        #expect(centres.count == 3)
        for (index, x) in centres.enumerated() { #expect(abs(x - Double(index) * 20) < 1e-3) }
    }

    @Test("an assembly inside an assembly loads each leaf once")
    func nestedAssembly() async throws {
        let doc = try #require(Document.create())
        let inner = try Self.assembly(parts: 2, in: doc)
        let outer = doc.newShapeLabel()
        doc.addComponent(assemblyLabelId: outer, shapeLabelId: inner, translation: (0, 50, 0))
        let loose = doc.addShape(try Self.box(7), makeAssembly: false)
        doc.addComponent(assemblyLabelId: outer, shapeLabelId: loose, translation: (0, 100, 0))
        let url = try Self.write(doc, "nested.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await Self.load(url)
        #expect(result.shapesWithColors.count == 3)
        #expect(result.shapesWithColors.map { Self.solidCount($0.shape) }.reduce(0, +) == 3)
        // The inner assembly sits at y = 50 and the loose box at y = 100; the solids keep both
        // placements, the inner one's own (x) and its parent's (y).
        let centres = try result.shapesWithColors.map { try Self.centre(of: $0.shape) }
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        #expect(centres.count == 3)
        if centres.count == 3 {
            #expect(abs(centres[0].x - 0) < 1e-3 && abs(centres[0].y - 50) < 1e-3)
            #expect(abs(centres[1].x - 20) < 1e-3 && abs(centres[1].y - 50) < 1e-3)
            #expect(abs(centres[2].x - 0) < 1e-3 && abs(centres[2].y - 100) < 1e-3)
        }
    }

    @Test("a single solid is still one body")
    func singleSolid() async throws {
        let doc = try #require(Document.create())
        _ = doc.addShape(try Self.box(4), makeAssembly: false)
        let url = try Self.write(doc, "single.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await Self.load(url)
        #expect(result.shapesWithColors.count == 1)
    }

    @Test("a compound that is the only thing in the file is still loaded")
    func lonelyCompound() async throws {
        let doc = try #require(Document.create())
        let compound = try #require(Shape.compound([try Self.box(2), try Self.box(3)]))
        _ = doc.addShape(compound, makeAssembly: false)
        let url = try Self.write(doc, "compound.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await Self.load(url)
        #expect(!result.shapesWithColors.isEmpty, "the compound is the model, not a grouping")
        #expect(result.shapesWithColors.map { Self.solidCount($0.shape) }.reduce(0, +) == 2)
    }
}
