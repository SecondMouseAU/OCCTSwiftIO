import Foundation
import Testing

@testable import OCCTSwiftIO

/// What SwiftDWG could not read, and what it counts without a layer, as `DrawingWarning`s.
///
/// SwiftDWG hands a drawing to SwiftDXF as DXF text, and writes an entity it could not read as a
/// bare `UNREADABLE_<type>` record, so the mapping is tested on DXF text written the same way.
@Suite("Unreadable records")
struct DrawingUnreadableTests {

    /// A drawing with unreadable records in model space (one of them flagged as paper space), in a
    /// block that an `INSERT` places, and in a block nothing inserts.
    static let dxf: String = [
        "0", "SECTION", "2", "BLOCKS",
        "0", "BLOCK", "2", "TAG", "10", "0", "20", "0",
        "0", "UNREADABLE_LINE", "5", "C1",
        "0", "ENDBLK",
        "0", "BLOCK", "2", "UNUSED", "10", "0", "20", "0",
        "0", "UNREADABLE_POLYLINE", "5", "C2",
        "0", "ENDBLK",
        "0", "ENDSEC",
        "0", "SECTION", "2", "ENTITIES",
        "0", "LINE", "8", "0", "10", "0", "20", "0", "11", "1", "21", "1",
        "0", "UNREADABLE_OBJECT", "5", "A1",
        "0", "UNREADABLE_OBJECT", "5", "A2",
        "0", "UNREADABLE_LAYER", "5", "54",
        "0", "UNREADABLE_LINE", "5", "A3", "67", "1",
        "0", "INSERT", "5", "A4", "8", "0", "2", "TAG", "10", "0", "20", "0",
        "0", "ENDSEC", "0", "EOF",
    ].joined(separator: "\n")

    static func warnings(_ options: DrawingLoader.Options = .init()) throws -> [DrawingWarning] {
        let url = try DrawingLoaderTests.temporaryFile("unreadable.dxf", Data(dxf.utf8))
        return try DrawingLoader.read(from: url, options: options).warnings
    }

    static func unreadable(_ warnings: [DrawingWarning], _ type: String) -> DrawingWarning? {
        warnings.first { $0.kind == .unreadable && $0.type == type }
    }

    @Test("what could not be read is one .unreadable warning per type, without the prefix")
    func perType() throws {
        let warnings = try Self.warnings()
        let types = warnings.filter { $0.kind == .unreadable }.compactMap(\.type)
        #expect(types == ["LAYER", "LINE", "OBJECT"])

        if let object = Self.unreadable(warnings, "OBJECT") {
            #expect(object.count == 2)
            #expect(object.layer == nil)
            #expect(object.message == "objects: 2 could not be read")
        } else {
            Issue.record("no warning for the unreadable objects")
        }
        if let layer = Self.unreadable(warnings, "LAYER") {
            #expect(layer.count == 1)
            #expect(layer.message == "LAYER table records: 1 could not be read")
        } else {
            Issue.record("no warning for the unreadable layer")
        }
    }

    @Test("an unreadable record is reported once: not as skipped, and not as paper space")
    func reportedOnce() throws {
        let warnings = try Self.warnings()
        #expect(!warnings.contains { $0.kind == .skippedEntities })
        #expect(!warnings.contains { $0.kind == .paperSpaceEntities })
        #expect(!warnings.contains { $0.type?.hasPrefix("UNREADABLE_") == true })
    }

    @Test("with blocks expanded, an unreadable record of an inserted block counts for each insert")
    func expandedBlocks() throws {
        let warnings = try Self.warnings(.init(expandBlocks: true))
        // One in paper space, one in the block TAG that the INSERT expands. The block nothing
        // inserts is not part of the drawing, and its POLYLINE is not counted.
        if let line = Self.unreadable(warnings, "LINE") {
            #expect(line.count == 2)
            #expect(!line.message.contains("block definitions"))
        } else {
            Issue.record("no warning for the unreadable lines")
        }
        #expect(Self.unreadable(warnings, "POLYLINE") == nil)
    }

    @Test("with blocks left alone, the block definitions are counted too")
    func unexpandedBlocks() throws {
        let warnings = try Self.warnings(.init(expandBlocks: false))
        if let line = Self.unreadable(warnings, "LINE") {
            #expect(line.count == 2)
            #expect(line.message == "LINE entities: 2 could not be read (1 in block definitions)")
        } else {
            Issue.record("no warning for the unreadable lines")
        }
        if let polyline = Self.unreadable(warnings, "POLYLINE") {
            #expect(polyline.count == 1)
            #expect(polyline.message.hasSuffix("(1 in block definitions)"))
        } else {
            Issue.record("no warning for the unreadable polyline")
        }
    }

    @Test("a DXF's skipped entities keep their layer; a DWG's carry none")
    func layerOfSkippedEntities() throws {
        let skipped = [
            "0", "SECTION", "2", "ENTITIES",
            "0", "SOLID", "8", "FILL", "10", "0", "20", "0",
            "0", "SOLID", "8", "OTHER", "10", "0", "20", "0",
            "0", "ENDSEC", "0", "EOF",
        ].joined(separator: "\n")
        let url = try DrawingLoaderTests.temporaryFile("solids.dxf", Data(skipped.utf8))
        let fromDXF = try DrawingLoader.read(from: url).warnings.filter {
            $0.kind == .skippedEntities
        }
        #expect(fromDXF.map(\.layer) == ["FILL", "OTHER"])

        // The same counts for a format that does not tell the layer: one warning per type.
        let drawing = try DXF.read(contentsOf: url)
        let unknown = DrawingLoader.skippedWarnings(for: drawing, layersKnown: false)
        #expect(unknown.count == 1)
        #expect(unknown.first?.type == "SOLID" && unknown.first?.count == 2)
        #expect(unknown.first?.layer == nil)
    }

    @Test("the skipped entities of a DWG written by AutoCAD are reported without a layer")
    func autocadDWGSkippedWithoutLayer() throws {
        let result = try DrawingLoader.read(
            from: DrawingLoaderTests.autocad("anonymous-names.dwg"))
        let skipped = result.warnings.filter { $0.kind == .skippedEntities }
        // Each of the five blocks holds one attribute definition, which has no entity form.
        #expect(skipped.count == 1)
        #expect(skipped.first?.type == "ATTDEF" && skipped.first?.count == 5)
        #expect(skipped.first?.layer == nil)
        #expect(!result.warnings.contains { $0.kind == .unreadable })
    }
}
