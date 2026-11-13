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
    /// another byte; do not look for one inside the test process, because some bytes make
    /// SwiftDWG trap instead of throw.
    static let invertedBytes: [(offset: Int, type: String, entities: Int)] = [
        (18328, "LINE", 7), (17992, "DIMSTYLE", 8),
    ]

    @Test(
        "a DWG damaged in one entity or record is read without it, and the loaders say so",
        arguments: invertedBytes)
    func lostRecordIsReported(damage: (offset: Int, type: String, entities: Int)) throws {
        let url = try Self.plateWithByteInverted(at: damage.offset)

        let result = try DrawingLoader.read(from: url)
        #expect(result.drawing.entities.count == damage.entities)
        let unreadable = result.warnings.filter { $0.kind == .unreadable }
        #expect(unreadable.map(\.type) == [damage.type])
        #expect(unreadable.first?.count == 1)
        #expect(unreadable.first?.layer == nil)
        #expect(!result.warnings.contains { $0.kind == .skippedEntities })

        // `DWGLoader` says the same, as text.
        let conversion = try DWGLoader.readEntities(from: url)
        #expect(conversion.warnings == unreadable.map(\.message))
        #expect(conversion.drawing.skipped["UNREADABLE_\(damage.type)"] == 1)
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
