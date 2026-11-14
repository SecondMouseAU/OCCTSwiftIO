import Foundation
import Testing

@testable import OCCTSwiftIO

/// What a DWG that cannot be read does: it throws a `DWG.Error` from both loaders, and what
/// SwiftDWG leaves out of a drawing it did read comes through as a warning.
@Suite("Damaged DWG files")
struct DWGDamagedFileTests {

    static var plateBytes: Data {
        get throws {
            try Data(
                contentsOf: DrawingLoaderTests.fixtures.appendingPathComponent("DWG/plate.dwg"))
        }
    }

    /// The bytes with the version code at the start replaced.
    static func relabelled(_ data: Data, as code: String) -> Data {
        Data(code.utf8) + data.dropFirst(6)
    }

    /// Each way a DWG can be unreadable, with the error SwiftDWG gives for it.
    ///
    /// The damage is to the file's structure (its start, its version, its length), so the
    /// outcome does not depend on which entities a drawing holds.
    static func cases() throws -> [(name: String, data: Data, error: DWG.Error)] {
        let plate = try plateBytes
        return [
            ("empty", Data(), .notADWG),
            ("not a drawing", Data("this is not a drawing".utf8), .notADWG),
            ("release 12", relabelled(plate, as: "AC1009"), .unsupportedVersion("AC1009")),
            ("a newer release", relabelled(plate, as: "AC1033"), .unsupportedVersion("AC1033")),
            ("only the version code", Data("AC1032".utf8), .truncated("the file header")),
        ]
    }

    // MARK: DWGLoader

    @Test("DWGLoader throws the DWG.Error for a file that is not a readable DWG")
    func dwgLoaderThrows() throws {
        for (name, data, expected) in try Self.cases() {
            let url = try DrawingLoaderTests.temporaryFile("damaged.dwg", data)
            do {
                _ = try DWGLoader.readEntities(from: url)
                Issue.record("\(name): expected \(expected), but the file was read")
            } catch let error as DWG.Error {
                // The case is pinned; the text of `truncated` and `invalid` is SwiftDWG's.
                switch (error, expected) {
                case (.truncated, .truncated), (.invalid, .invalid): break
                default: #expect(error == expected, "\(name)")
                }
            } catch {
                Issue.record("\(name): expected a DWG.Error, got \(error)")
            }
        }
    }

    @Test("DWGLoader throws for a DWG cut off in the middle, and for zeros after the header")
    func dwgLoaderThrowsForDamagedBody() throws {
        let plate = try Self.plateBytes
        let halved = try DrawingLoaderTests.temporaryFile(
            "halved.dwg", plate.prefix(plate.count / 2))
        #expect(throws: DWG.Error.self) { try DWGLoader.readEntities(from: halved) }

        let zeroed = try DrawingLoaderTests.temporaryFile(
            "zeroed.dwg", Data("AC1032".utf8) + Data(count: 4096))
        #expect(throws: DWG.Error.self) { try DWGLoader.readEntities(from: zeroed) }
    }

    // MARK: what a damaged DWG still gives

    /// `plate.dwg` with the byte at `offset` inverted, in a file of its own.
    static func plateWithByteInverted(at offset: Int) throws -> URL {
        var bytes = try plateBytes
        bytes[offset] ^= 0xFF
        return try DrawingLoaderTests.temporaryFile("inverted.dwg", bytes)
    }

    /// One inverted byte of `plate.dwg` that SwiftDWG 0.1 reads past, losing a line, or a
    /// dimension style.
    ///
    /// These pin what that release does with this damage. If a later one reads more of it, pick
    /// another byte.
    static let invertedBytes: [(offset: Int, type: String, entities: Int, message: String)] = [
        (18328, "LINE", 7, "LINE entities: 1 could not be read"),
        (17992, "DIMSTYLE", 8, "DIMSTYLE table records: 1 could not be read"),
    ]

    @Test(
        "a DWG damaged in one entity or record is read without it, and the loaders say so",
        arguments: invertedBytes)
    func lostRecordIsReported(
        damage: (offset: Int, type: String, entities: Int, message: String)
    ) throws {
        let url = try Self.plateWithByteInverted(at: damage.offset)

        let result = try DrawingLoader.read(from: url)
        #expect(result.drawing.entities.count == damage.entities)
        let unreadable = result.warnings.filter { $0.kind == .unreadable }
        #expect(unreadable.map(\.type) == [damage.type])
        #expect(unreadable.first?.count == 1)
        #expect(unreadable.first?.message == damage.message)
        #expect(unreadable.first?.layer == nil)
        #expect(!result.warnings.contains { $0.kind == .skippedEntities })

        // `DWGLoader` says the same, as text.
        let conversion = try DWGLoader.readEntities(from: url)
        #expect(conversion.warnings == [damage.message])
        #expect(conversion.drawing.skipped["UNREADABLE_\(damage.type)"] == 1)
    }

    /// One inverted byte of `dimassoc-perpendicular.dwg`, which AutoCAD wrote: it loses an
    /// arrowhead (a `SOLID`) of the dimension's own block, `*D1`, which no `INSERT` places.
    ///
    /// The same caution applies as for `invertedBytes`.
    @Test("an entity lost in a block definition is counted when blocks are not expanded")
    func lostInBlockDefinition() throws {
        var bytes = try Data(contentsOf: DrawingLoaderTests.autocad("dimassoc-perpendicular.dwg"))
        bytes[10662] ^= 0xFF
        let url = try DrawingLoaderTests.temporaryFile("inverted.dwg", bytes)

        // Expanded, the drawing is its three entities, and the block is not part of it.
        let expanded = try DWGLoader.readEntities(from: url, options: .init(expandBlocks: true))
        #expect(expanded.drawing.entities.count == 3)
        #expect(expanded.warnings.isEmpty)
        let expandedResult = try DrawingLoader.read(from: url, options: .init(expandBlocks: true))
        #expect(!expandedResult.warnings.contains { $0.kind == .unreadable })

        // Left alone, the blocks are the caller's to walk, so the loss is reported.
        let kept = try DWGLoader.readEntities(from: url, options: .init(expandBlocks: false))
        #expect(kept.warnings == ["SOLID entities: 1 could not be read (1 in block definitions)"])
        let keptResult = try DrawingLoader.read(from: url, options: .init(expandBlocks: false))
        let unreadable = keptResult.warnings.filter { $0.kind == .unreadable }
        #expect(unreadable.map(\.type) == ["SOLID"])
        #expect(unreadable.first?.count == 1)
    }

    /// A sample of the bytes of a DWG: every `stride`th, and `extra`.
    ///
    /// Inverting each in turn must give a drawing or a `DWG.Error`. This is a sample, as it is in
    /// SwiftDWG's own checks, not a proof for every byte. In `plate.dwg`, byte 840 made SwiftDWG
    /// trap before its 0.1.0 release, and byte 219 is in the 64-bit address of the page map, which
    /// that release refuses when it is too large. In `dimassoc-perpendicular.dwg`, byte 10662 is
    /// one that the damaged-entity tests read past.
    @Test(
        "a byte inverted anywhere in a sample gives a drawing or a DWG.Error, not a crash",
        .timeLimit(.minutes(1)),
        arguments: [
            ("DWG/plate.dwg", 401, [219, 840]),
            ("DWG/autocad/dimassoc-perpendicular.dwg", 601, [10662]),
        ] as [(String, Int, [Int])])
    func invertedByteSample(path: String, stride step: Int, extra: [Int]) throws {
        let original = try Data(
            contentsOf: DrawingLoaderTests.fixtures.appendingPathComponent(path))
        var drawings = 0
        var errors = 0
        for offset in Set(stride(from: 0, to: original.count, by: step)).union(extra).sorted() {
            var bytes = original
            bytes[offset] ^= 0xFF
            do {
                _ = try DWGLoader.read(data: bytes, options: .init())
                drawings += 1
            } catch is DWG.Error {
                // The first bytes are the version code, which any change refuses.
                if offset >= 6 { errors += 1 }
            } catch {
                Issue.record("\(path) byte \(offset): expected a DWG.Error, got \(error)")
            }
        }
        // The sample is worth something only if it reaches both outcomes past the version code.
        #expect(drawings > 0 && errors > 0, "\(path): \(drawings) read, \(errors) refused")
    }

    // MARK: DrawingLoader

    @Test("DrawingLoader throws the same DWG.Error for a file that is not a readable DWG")
    func drawingLoaderThrows() throws {
        for (name, data, expected) in try Self.cases() where !data.isEmpty {
            let url = try DrawingLoaderTests.temporaryFile("damaged.dwg", data)
            do {
                _ = try DrawingLoader.read(from: url)
                Issue.record("\(name): expected \(expected), but the file was read")
            } catch let error as DWG.Error {
                switch (error, expected) {
                case (.truncated, .truncated), (.invalid, .invalid): break
                default: #expect(error == expected, "\(name)")
                }
            } catch {
                Issue.record("\(name): expected a DWG.Error, got \(error)")
            }
        }
    }

    @Test("a file named .dwg that is not a DWG is a DWG.Error; a file that is nothing is not")
    func drawingLoaderByExtension() throws {
        let named = try DrawingLoaderTests.temporaryFile("plan.dwg", Data("hello".utf8))
        #expect(throws: DWG.Error.notADWG) { try DrawingLoader.read(from: named) }

        let unnamed = try DrawingLoaderTests.temporaryFile("plan.bin", Data("hello".utf8))
        #expect(throws: DrawingLoader.LoadError.self) { try DrawingLoader.read(from: unnamed) }
    }

    @Test("a DWG cut off in the middle throws a DWG.Error from DrawingLoader, by its bytes")
    func drawingLoaderThrowsForHalvedFile() throws {
        let plate = try Self.plateBytes
        let url = try DrawingLoaderTests.temporaryFile("halved.bin", plate.prefix(plate.count / 2))
        #expect(throws: DWG.Error.self) { try DrawingLoader.read(from: url) }
    }

    @Test("a DWG of a release SwiftDWG does not name is still told as a DWG")
    func newerReleaseIsStillADWG() throws {
        let newer = Self.relabelled(try Self.plateBytes, as: "AC1033")
        #expect(DrawingFormat.sniff(newer) == .dwg)
        #expect(DrawingFormat.sniff(Data("AC10".utf8)) == nil)
    }
}
