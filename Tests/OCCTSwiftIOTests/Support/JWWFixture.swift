import Foundation

/// Writes a minimal JWW file (version 700 header, then drawing entities) for tests.
///
/// The header layout mirrors SwiftJWW's reader and its own test builder, from which this is copied.
enum JWWFixture {

    struct Builder {
        var d = Data()
        mutating func u8(_ v: Int) { d.append(UInt8(v & 0xFF)) }
        mutating func u16(_ v: Int) {
            d.append(UInt8(v & 0xFF))
            d.append(UInt8((v >> 8) & 0xFF))
        }
        mutating func u32(_ v: Int) { for k in 0..<4 { d.append(UInt8((v >> (8 * k)) & 0xFF)) } }
        mutating func f64(_ v: Double) {
            withUnsafeBytes(of: v.bitPattern.littleEndian) { d.append(contentsOf: $0) }
        }
        mutating func emptyStr() { u8(0) }
        mutating func zeros(_ n: Int) { d.append(Data(count: n)) }

        /// Emit a minimal but byte-exact v700 header: every field zero or empty, except each layer
        /// group's scale denominator, which is `scales[group]` or 1, as Jw_cad writes an unscaled
        /// group.
        mutating func header(version: Int = 700, scales: [Int: Double] = [:]) {
            d.append(contentsOf: Array("JwwData.".utf8))
            u32(version)
            emptyStr()  // memo
            u32(0)
            u32(0)  // zumen, writeGLay
            for group in 0..<16 {
                u32(0)  // state
                u32(0)  // write layer
                f64(scales[group] ?? 1)  // scale denominator: 80 is 1:80
                u32(0)  // protection
                for _ in 0..<16 { zeros(8) }
            }  // layer-groups
            zeros(14 * 4)
            zeros(5 * 4)
            zeros(4)
            zeros(4)  // dummy, sunpou, dummy1, maxDrawWid
            zeros(8 * 2)
            zeros(8)
            zeros(4)
            zeros(4)
            zeros(8)
            zeros(8 * 2)
            zeros(8 * 2)
            for _ in 0..<(16 * 16) { emptyStr() }
            for _ in 0..<16 { emptyStr() }  // names
            zeros(8)
            zeros(8)
            zeros(4)
            zeros(8)  // kage...
            zeros(8)
            zeros(8)  // tenkuu (v>=300)
            zeros(4)
            zeros(8)
            zeros(8 * 2)
            zeros(8)
            zeros(8 * 2)
            for _ in 0..<8 { zeros(8 + 8 + 8 + 4) }  // zoom (v>=300)
            zeros(8 * 3)
            zeros(4)
            zeros(8 * 2)
            zeros(8)
            zeros(4)  // dDm (v>=300)
            zeros(8 * 10)
            zeros(8)  // fukusen, ryo
            for _ in 0..<10 { zeros(8) }
            for _ in 0..<10 { zeros(16) }  // Pen, PrtPen
            for _ in 0..<8 { zeros(16) }
            for _ in 0..<5 { zeros(20) }
            for _ in 0..<4 { zeros(16) }  // LType
            zeros(4 * 11)
            zeros(8)
            zeros(4 * 3)
            zeros(8 * 5)
            zeros(8 * 4)
            zeros(8)  // flags..solid
            if version >= 420 {
                for _ in 0..<257 { zeros(8) }  // SXF color display
                for _ in 0..<257 {
                    emptyStr()
                    zeros(16)
                }  // SXF color print
                for _ in 0..<33 { zeros(16) }  // SXF ltype pattern
                for _ in 0..<33 {
                    emptyStr()
                    zeros(4 + 80)
                }  // SXF ltype param
            }
            for _ in 0..<10 { zeros(8 * 3 + 4) }  // Moji[1..10]
            zeros(8 * 3)
            zeros(8)
            zeros(8)
            zeros(8)
            zeros(4)
            zeros(8 * 6)  // moji write settings
        }
        mutating func base(
            penStyle: Int = 1, color: Int = 2, layer: Int = 0, group: Int = 0, flags: Int = 0
        ) {
            u32(0)  // curve attribute
            u8(penStyle)
            u16(color)
            u16(0)  // pen width, present from v3.51
            u16(layer)
            u16(group)
            u16(flags)
        }

        /// The class tag of the next object.
        ///
        /// The class name the first time, then a reference to the index it took. Each class and
        /// each object takes the next index, from 1.
        mutating func objectTag(_ name: String) {
            if let index = classIndex[name] {
                u16(0x8000 | index)
            } else {
                classTag(name)
                classIndex[name] = nextIndex
                nextIndex += 1
            }
            nextIndex += 1
        }
        var classIndex: [String: Int] = [:]
        var nextIndex = 1
        mutating func str(_ s: String) {
            let a = Array(s.utf8)
            u8(a.count)
            d.append(contentsOf: a)
        }
        mutating func classTag(_ name: String) {
            u16(0xFFFF)
            u16(0x2bc)
            u16(name.utf8.count)
            d.append(contentsOf: Array(name.utf8))
        }
        // inline entity field groups (no object tag; used inside CDataSunpou)
        mutating func senFields(
            _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, layer: Int = 0
        ) {
            base(layer: layer)
            f64(x1)
            f64(y1)
            f64(x2)
            f64(y2)
        }
        mutating func mojiFields(_ text: String, at: (Double, Double) = (0, 0), layer: Int = 0) {
            base(layer: layer)
            f64(at.0)
            f64(at.1)
            f64(at.0)
            f64(at.1)  // end point
            u32(0)
            f64(2)
            f64(2)
            f64(0)
            f64(0)
            emptyStr()
            str(text)
        }
        mutating func tenFields(_ x: Double, _ y: Double, layer: Int = 0) {
            base(layer: layer)
            f64(x)
            f64(y)
            u32(0)
        }
    }

    /// The 100 x 60 plate of `Fixtures/DWG/plate.dwg` and `Fixtures/Drawing/plate.dxf`.
    ///
    /// Four lines and a circle of radius 5 at (30, 30), all on layer 0: the geometry only, without
    /// the dimensions of the DXF and DWG plates.
    static func plate() -> Data {
        var b = Builder()
        b.header()
        b.u16(5)  // array preamble: five objects
        let corners: [((Double, Double), (Double, Double))] = [
            ((0, 0), (100, 0)), ((100, 0), (100, 60)), ((100, 60), (0, 60)), ((0, 60), (0, 0)),
        ]
        for (i, line) in corners.enumerated() {
            if i == 0 {
                b.classTag("CDataSen")
            } else {
                b.u16(0x8001)  // back-reference to the CDataSen class
            }
            b.base(layer: 0)
            b.f64(line.0.0)
            b.f64(line.0.1)
            b.f64(line.1.0)
            b.f64(line.1.1)
        }
        b.classTag("CDataEnko")
        b.base(layer: 0)
        b.f64(30)  // centre x
        b.f64(30)  // centre y
        b.f64(5)  // radius
        b.f64(0)  // start
        b.f64(2 * .pi)  // sweep
        b.f64(0)  // tilt
        b.f64(1)  // ratio: a circle
        b.u32(1)  // full circle
        return b.d
    }

    /// One element of a fixture drawing, in drawn units.
    struct Item {
        enum Shape {
            case line(Double, Double, Double, Double)
            case point(Double, Double)
            case text(String, at: (Double, Double))
            /// A dimension stored as one record: its dimension line and value, and, in a file of
            /// version 4.20 or later, its two witness lines, two arrow points and two measured points.
            case dimensionRecord(
                line: (Double, Double, Double, Double), value: String, at: (Double, Double),
                witness: [(Double, Double, Double, Double)], arrows: [(Double, Double)],
                measured: [(Double, Double)])
            /// A block definition, numbered, with its members.
            case block(number: Int, name: String, members: [Item])
            /// A reference to block `number`, at `at`, unscaled and unrotated.
            case insert(number: Int, at: (Double, Double))
            /// A solid fill over four corners.
            case solid([(Double, Double)])
        }
        var shape: Shape
        var group = 0
        var layer = 0
        /// Jw_cad's attribute flags: 0x2000 on a dimension line, 0x40 on an arrow point, 0x4010 on
        /// a dimension value, 0x4110 on a radius value.
        var flags = 0
    }

    /// A drawing of `items`, with the layer groups at `scales` (1 where not given).
    static func drawing(_ items: [Item], version: Int = 700, scales: [Int: Double] = [:]) -> Data {
        var b = Builder()
        b.header(version: version, scales: scales)
        b.u16(items.count)  // array preamble
        for item in items { write(item, into: &b, version: version) }
        return b.d
    }

    private static func write(_ item: Item, into b: inout Builder, version: Int) {
        func base() { b.base(layer: item.layer, group: item.group, flags: item.flags) }
        switch item.shape {
        case .line(let x1, let y1, let x2, let y2):
            b.objectTag("CDataSen")
            base()
            b.f64(x1)
            b.f64(y1)
            b.f64(x2)
            b.f64(y2)
        case .point(let x, let y):
            b.objectTag("CDataTen")
            base()
            b.f64(x)
            b.f64(y)
            b.u32(0)  // not a temporary point
        case .text(let string, let at):
            b.objectTag("CDataMoji")
            base()
            b.f64(at.0)
            b.f64(at.1)
            b.f64(at.0)
            b.f64(at.1)  // end point
            b.u32(0)  // text kind
            b.f64(2)
            b.f64(2)  // width, height
            b.f64(0)  // spacing
            b.f64(0)  // angle, degrees
            b.emptyStr()  // font
            b.str(string)
        case .dimensionRecord(let line, let value, let at, let witness, let arrows, let measured):
            b.objectTag("CDataSunpou")
            base()
            b.senFields(line.0, line.1, line.2, line.3, layer: item.layer)
            b.mojiFields(value, at: at, layer: item.layer)
            if version >= 420 {
                b.u16(0)  // SXF mode
                for w in witness { b.senFields(w.0, w.1, w.2, w.3, layer: item.layer) }
                for p in arrows + measured { b.tenFields(p.0, p.1, layer: item.layer) }
            }
        case .block(let number, let name, let members):
            b.objectTag("CDataList")
            base()
            b.u32(number)
            b.u32(0)
            b.u32(0)  // referenced, time
            b.str(name)
            b.u16(members.count)
            for member in members { write(member, into: &b, version: version) }
        case .solid(let corners):
            b.objectTag("CDataSolid")
            base()  // colour 2, so no extra colour word follows the corners
            for corner in corners.prefix(4) {
                b.f64(corner.0)
                b.f64(corner.1)
            }
        case .insert(let number, let at):
            b.objectTag("CDataBlock")
            base()
            b.f64(at.0)
            b.f64(at.1)
            b.f64(1)
            b.f64(1)  // scale x, y
            b.f64(0)  // rotation
            b.u32(number)
        }
    }

    /// The 100 x 60 plate drawn at 1:10 in layer group 0, with its width dimensioned.
    ///
    /// The dimension is kept the way Jw_cad keeps one it did not store as a dimension: a dimension
    /// line, two extension lines, two arrow points and the value `100`, loose on layer E with the
    /// dimension flags. A radius value `R5` on the same layer has no dimension to explain it.
    static func dimensionedPlate() -> Data {
        let dimension = 0xE
        let outline: [Item] = [
            (0.0, 0.0, 10.0, 0.0), (10, 0, 10, 6), (10, 6, 0, 6), (0, 6, 0, 0),
        ].map { Item(shape: .line($0.0, $0.1, $0.2, $0.3)) }
        let pieces: [Item] = [
            Item(shape: .line(0, -2, 10, -2), layer: dimension, flags: 0x2000),
            Item(shape: .line(0, -0.5, 0, -2), layer: dimension, flags: 0x2000),
            Item(shape: .line(10, -0.5, 10, -2), layer: dimension, flags: 0x2000),
            Item(shape: .point(0, -2), layer: dimension, flags: 0x40),
            Item(shape: .point(10, -2), layer: dimension, flags: 0x40),
            Item(shape: .text("100", at: (4.5, -1.8)), layer: dimension, flags: 0x4010),
            Item(shape: .text("R5", at: (3, 3)), layer: dimension, flags: 0x4110),
        ]
        return drawing(outline + pieces, scales: [0: 10])
    }

    /// A line 10 drawn units long in layer group 0 at 1:10, and one 5 long in group 1 at 1:1.
    static func mixedScales() -> Data {
        drawing(
            [
                Item(shape: .line(0, 0, 10, 0)),
                Item(shape: .line(0, 1, 5, 1), group: 1),
            ], scales: [0: 10, 1: 1])
    }

    /// A line 10 drawn units long in layer group 0, which states a scale of 0.
    static func unstatedScale() -> Data {
        drawing([Item(shape: .line(0, 0, 10, 0))], scales: [0: 0])
    }

    /// The plate's width at 1:10, dimensioned by one stored dimension record whose value is `100`.
    ///
    /// In a file of version 4.20 or later the record has its measured points; in an older file
    /// (`version` 351) it has only the dimension line and the value.
    static func storedDimension(version: Int = 700) -> Data {
        drawing(
            [
                Item(shape: .line(0, 0, 10, 0)),
                Item(
                    shape: .dimensionRecord(
                        line: (0, -2, 10, -2), value: "100", at: (4.5, -1.8),
                        witness: [(0, 0, 0, -2), (10, 0, 10, -2)], arrows: [(0, -2), (10, -2)],
                        measured: [(0, 0), (10, 0)]), layer: 0xE),
            ], version: version, scales: [0: 10])
    }

    /// A block of one line, 1 drawn unit long, placed at (2, 3) in layer group 0 at 1:10.
    static func blockAtScale() -> Data {
        drawing(
            [
                Item(
                    shape: .block(
                        number: 1, name: "B", members: [Item(shape: .line(0, 0, 1, 0))])),
                Item(shape: .insert(number: 1, at: (2, 3))),
            ], scales: [0: 10])
    }

    /// A line in layer group 0 at 1:10 and one in group 1, which states a scale of 0.
    static func scaledBesideUnstated() -> Data {
        drawing(
            [
                Item(shape: .line(0, 0, 10, 0)),
                Item(shape: .line(0, 1, 5, 1), group: 1),
            ], scales: [0: 10, 1: 0])
    }

    /// The plate's outline at 1:1 with a solid fill over it.
    static func solidFill() -> Data {
        drawing([
            Item(shape: .line(0, 0, 100, 0)),
            Item(shape: .solid([(0, 0), (100, 0), (100, 60), (0, 60)])),
        ])
    }
}
