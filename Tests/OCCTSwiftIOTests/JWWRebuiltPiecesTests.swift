import Foundation
import SwiftJWW
import Testing

@testable import OCCTSwiftIO

/// Each dimension SwiftJWW rebuilds from loose pieces lists the pieces it was built from (#77).
@Suite("JWW rebuilt dimensions, with their pieces")
struct JWWRebuiltPiecesTests {

    typealias Piece = DrawingResult.RebuiltDimension.Piece

    /// The rebuilt dimension whose `.dimension` entity has the text `value`.
    static func rebuilt(_ value: String, in result: DrawingResult)
        -> DrawingResult.RebuiltDimension?
    {
        result.rebuiltDimensions.first { rebuilt in
            guard let index = result.drawing.identities.firstIndex(of: rebuilt.identity),
                case .dimension(let dimension) = result.drawing.entities[index]
            else { return false }
            return dimension.textOverride == value
        }
    }

    @Test("a rebuilt dimension lists its pieces at full size, on the layers written")
    func plate() throws {
        let result = try JWWFullSizeTests.read("plate.jww", JWWFixture.dimensionedPlate())
        #expect(result.rebuiltDimensions.count == 1)
        // The plate is drawn at 1:10; the outline is elements 0 to 3 and `R5` is element 10.
        #expect(
            result.rebuiltDimensions.first?.pieces == [
                Piece(
                    kind: .dimensionLine, points: [DXF.Point(0, -20), DXF.Point(100, -20)],
                    layer: "0-E", elementIndex: 4),
                Piece(
                    kind: .extensionLine, points: [DXF.Point(0, -5), DXF.Point(0, -20)],
                    layer: "0-E", elementIndex: 5),
                Piece(
                    kind: .extensionLine, points: [DXF.Point(100, -5), DXF.Point(100, -20)],
                    layer: "0-E", elementIndex: 6),
                Piece(
                    kind: .arrowPoint, points: [DXF.Point(0, -20)], layer: "0-E", elementIndex: 7),
                Piece(
                    kind: .arrowPoint, points: [DXF.Point(100, -20)], layer: "0-E",
                    elementIndex: 8),
                Piece(
                    kind: .valueText, points: [DXF.Point(45, -18)], layer: "0-E", elementIndex: 9),
            ])
    }

    @Test("chained dimensions share pieces, and a second copy of a value is listed as one")
    func chain() throws {
        let result = try JWWFullSizeTests.read("chain.jww", JWWFixture.chainedDimensions())
        #expect(result.rebuiltDimensions.count == 2)
        let forty = try #require(Self.rebuilt("40", in: result))
        let sixty = try #require(Self.rebuilt("60", in: result))
        #expect(forty.pieces.map(\.elementIndex) == [0, 1, 2, 4, 5, 7])
        #expect(
            forty.pieces.map(\.kind) == [
                .dimensionLine, .extensionLine, .extensionLine, .arrowPoint, .arrowPoint,
                .valueText,
            ])
        #expect(sixty.pieces.map(\.elementIndex) == [0, 2, 3, 5, 6, 8, 9])
        #expect(
            sixty.pieces.map(\.kind) == [
                .dimensionLine, .extensionLine, .extensionLine, .arrowPoint, .arrowPoint,
                .valueText, .valueTextCopy,
            ])
        // The one dimension line runs the whole chain, past the arrow points of each.
        let line = Piece(
            kind: .dimensionLine, points: [DXF.Point(0, -20), DXF.Point(100, -20)], layer: "0-E",
            elementIndex: 0)
        #expect(forty.pieces.first == line && sixty.pieces.first == line)
        #expect(Set((forty.pieces + sixty.pieces).map(\.elementIndex)) == Set(0..<10))
    }

    @Test("pieces take the scale and layer names of their own layer group")
    func anotherGroup() throws {
        // Group A at 1:5, while group 0 states 1:10.
        let result = try JWWFullSizeTests.read(
            "chain-a.jww", JWWFixture.chainedDimensions(group: 0xA, scale: 5))
        #expect(result.layerGroupScales == [.init(group: 0xA, scale: 5)])
        #expect(result.rebuiltDimensions.count == 2)
        #expect(Set(result.rebuiltDimensions.flatMap(\.pieces).map(\.layer)) == ["A-E"])
        let twenty = try #require(Self.rebuilt("20", in: result))
        #expect(
            twenty.pieces == [
                Piece(
                    kind: .dimensionLine, points: [DXF.Point(0, -10), DXF.Point(50, -10)],
                    layer: "A-E", elementIndex: 0),
                Piece(
                    kind: .extensionLine, points: [DXF.Point(0, -2.5), DXF.Point(0, -10)],
                    layer: "A-E", elementIndex: 1),
                Piece(
                    kind: .extensionLine, points: [DXF.Point(20, -2.5), DXF.Point(20, -10)],
                    layer: "A-E", elementIndex: 2),
                Piece(
                    kind: .arrowPoint, points: [DXF.Point(0, -10)], layer: "A-E", elementIndex: 4),
                Piece(
                    kind: .arrowPoint, points: [DXF.Point(20, -10)], layer: "A-E", elementIndex: 5
                ),
                Piece(
                    kind: .valueText, points: [DXF.Point(7.5, -9)], layer: "A-E", elementIndex: 7),
            ])
    }

    /// `layerNamePrefix` is the one copy of the writer's layer naming left here.
    @Test("a layer group's prefix starts every layer name the writer gives the group")
    func prefixMatchesTheWriter() {
        for group in 0..<16 {
            let prefix = DrawingResult.LayerGroupScale(group: group, scale: 1).layerNamePrefix
            for layer in 0..<16 {
                let name = DXFWriter.layerName(group: group, layer: layer)
                #expect(name.hasPrefix(prefix), "\(name) does not start with \(prefix)")
                #expect(name.dropFirst(prefix.count).count == 1)
            }
        }
    }

    @Test(
        "the JNR 2120: the 29 rebuilt dimensions are built from the 125 elements on layer 0-E",
        .enabled(if: JWWFullSizeTests.isLocal("2120.jww"), "2120.jww is not in the repository"))
    func the2120() throws {
        let url = JWWFullSizeTests.local("2120.jww")
        let result = try DrawingLoader.read(from: url)
        let jww = try JWW.read(data: Data(contentsOf: url))
        let onLayerE = Set(
            jww.elements.indices.filter {
                let attributes = jww.elements[$0].attributes
                return DXFWriter.layerName(group: attributes.layerGroup, layer: attributes.layer)
                    == "0-E"
            })
        #expect(onLayerE.count == 125)
        #expect(result.rebuiltDimensions.count == 29)

        let pieces = result.rebuiltDimensions.flatMap(\.pieces)
        #expect(Set(pieces.map(\.elementIndex)) == onLayerE)
        #expect(Set(pieces.map(\.layer)) == ["0-E"])
        // A piece two dimensions share is listed under each, so these add up to more than 125.
        #expect(
            Dictionary(grouping: pieces, by: \.kind).mapValues(\.count) == [
                .valueText: 29, .valueTextCopy: 1, .arrowPoint: 58, .dimensionLine: 30,
                .extensionLine: 56,
            ])

        for rebuilt in result.rebuiltDimensions {
            #expect(rebuilt.pieces.filter { $0.kind == .valueText }.count == 1)
            let arrows = rebuilt.pieces.filter { $0.kind == .arrowPoint }.flatMap(\.points)
            guard arrows.count == 2,
                let index = result.drawing.identities.firstIndex(of: rebuilt.identity),
                case .dimension(let dimension) = result.drawing.entities[index],
                let measured = dimension.computedMeasurement
            else {
                Issue.record("no two arrow points or no measurement for \(rebuilt.identity)")
                continue
            }
            // The arrow points are the measured distance apart, at full size, to the six decimals
            // the DXF text keeps (the largest difference on this drawing is 7e-7).
            let distance = hypot(arrows[1].x - arrows[0].x, arrows[1].y - arrows[0].y)
            #expect(abs(distance - measured) <= 1e-5, "\(distance) against \(measured)")
        }
    }

    static let realDrawings = ["2120.jww", "dd12.jww"]

    @Test(
        "on the real drawings, the extension lines are the ones SwiftJWW's recovery found",
        .enabled(
            if: realDrawings.contains(where: JWWFullSizeTests.isLocal),
            "the real drawings are not in the repository"))
    func linesAgreeWithTheRecovery() throws {
        for name in Self.realDrawings where JWWFullSizeTests.isLocal(name) {
            let url = JWWFullSizeTests.local(name)
            let result = try DrawingLoader.read(from: url)
            let jww = try JWW.read(data: Data(contentsOf: url))
            // The element indices of each recovered dimension's extension lines.
            var extensionLines: [[Int]: Set<Int>] = [:]
            for found in jww.recoveringDimensions().dimensions {
                extensionLines[found.elementIndices] = Set(
                    found.elementIndices.filter { index in
                        guard case .line(let a, let b, _, _) = jww.elements[index].entity else {
                            return false
                        }
                        return found.dimension.extensionLines.contains { $0.a == a && $0.b == b }
                    })
            }
            #expect(!result.rebuiltDimensions.isEmpty)
            for rebuilt in result.rebuiltDimensions {
                let expected = extensionLines[rebuilt.pieces.map(\.elementIndex)]
                let labelled = Set(
                    rebuilt.pieces.filter { $0.kind == .extensionLine }.map(\.elementIndex))
                #expect(expected == labelled, "\(name): \(rebuilt.identity)")
            }
        }
    }
}
