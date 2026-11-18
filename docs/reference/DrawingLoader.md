---
title: DrawingLoader
parent: API Reference
---

# DrawingLoader

One entry point for 2D drawing import. It reads a DXF, a DWG or a JWW and returns one
`DrawingResult`, so a consumer neither picks a reader nor branches on the file extension.

## `DrawingLoader.read(from:options:)`

```swift
public static func read(from url: URL, options: Options = .init()) throws -> DrawingResult
```

- **Parameters:** `url`, the file. `options`, see below.
- **Returns:** a `DrawingResult`.
- **Throws:** `DrawingLoader.LoadError.unrecognizedFormat` when the file is none of the three;
  `DWG.Error` for a DWG that cannot be read (`.unsupportedVersion`, `.truncated`, `.invalid`, and
  `.notADWG` for a file named `.dwg` whose bytes are not one); the reader's own error for a DXF or a
  JWW. SwiftDWG runs in this process; a corrupt DWG is meant to end in `DWG.Error` and not to trap
  or hang, which is checked by sampling and not proved (see [DWGLoader](DWGLoader.md)).

The format is told from the file's bytes (`DrawingFormat.sniff`): JWW, then a DWG (`AC` and four
digits, whatever the release), then a DXF. The file extension is consulted only when the bytes say
nothing, so a DXF named `.dwg` is read as a DXF. DXF is read by SwiftDXF, DWG by
[SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG) (see [DWGLoader](DWGLoader.md)), and JWW by
SwiftJWW and passed through its DXF writer, at full size and with the dimensions it rebuilds (see
[JWW](#jww) below).

## `DrawingLoader.Options`

| Option | Default | Meaning |
|---|---|---|
| `expandBlocks` | `true` | Flatten block references into the entities, hatches and leaders. Each expanded entity's identity records the references it came through. |
| `skipPaperSpace` | `false` | Leave paper-space entities out, as a model-space read does. |

## `DrawingResult`

```swift
public struct DrawingResult: Sendable {
    public var drawing: DXF.Drawing       // identities[i] identifies entities[i]
    public var source: DrawingSource
    public var warnings: [DrawingWarning]
    public var rebuiltDimensions: [RebuiltDimension]                    // JWW only, so far
    public var unexplainedDimensionValues: [UnexplainedDimensionValue]  // JWW only
    public var layerGroupScales: [LayerGroupScale]                      // JWW only
}
```

The last three are empty for a DXF and a DWG. The initialiser takes them as defaulted parameters.

```swift
extension DrawingResult {
    public struct RebuiltDimension: Sendable, Equatable {
        public var identity: DXF.Identity     // of the .dimension entity in drawing
        public init(identity: DXF.Identity)
    }
    public struct UnexplainedDimensionValue: Sendable, Equatable {
        public var text: String               // as written: "1,930", "R5"
        public var position: DXF.Point        // at full size
        public var layer: String              // "0-E"
        public init(text: String, position: DXF.Point, layer: String)
    }
    public struct LayerGroupScale: Sendable, Equatable {
        public var group: Int                 // 0 to 15
        public var scale: Double              // the factor applied: 80 for 1:80, 1 when none is stated
        public var layerNamePrefix: String    // "0-" for group 0
        public init(group: Int, scale: Double)
    }
}
```

`DrawingSource` records the file's `fileName`, its `sha256` (empty where CryptoKit is unavailable),
its `format` (`.dxf`, `.dwg`, `.jww`) and the format's own `version`: `$ACADVER` for a DXF and the
version code for a DWG (both like `AC1032`), the file version for a JWW (`700`).

## JWW

A JWW is drawn on a sheet: each of its 16 layer groups has a scale, such as 1:80, and its lengths
are drawn at that scale. SwiftJWW's DXF writer is asked for full size and for the dimensions it can
rebuild (`DXFWriter.Options(fullSize: true, recoversDimensions: true)`), so:

- **The drawing is at full size.** Each element is multiplied by the scale of its own layer group.
  `layerGroupScales` lists each group that holds a top-level element, with the scale applied (80
  for 1:80). A group that states no usable scale is read at drawn size: its scale is listed as 1
  and it has a `scaleNotStated` warning. When the groups in use have different scales, each is at
  its own full size, so they no longer sit relative to each other as on the sheet; that is a
  `mixedScales` warning.
- **Layers are named `<group>-<layer>`** in hexadecimal, as Jw_cad names them in its own DXF and DWG
  export: layer 14 of group 0 is `0-E`. `LayerGroupScale.layerNamePrefix` gives a group's prefix
  (`0-`).
- **Dimensions kept as loose pieces are rebuilt.** Many Jw_cad drawings keep a dimension as a
  dimension line, extension lines, two arrow points and a value text, marked with Jw_cad's dimension
  flags, not as one dimension record. SwiftJWW pairs each value with the two arrow points whose
  distance, at the group's scale, gives it, and the pair comes back as one rotated linear
  `.dimension`, its pieces in the block it names. That is an inference, so `rebuiltDimensions`
  lists the identity of each such entity: a `.dimension` not listed there was stored in the file.
  Which pieces each was built from is not recorded yet
  ([SwiftJWW#22](https://github.com/SecondMouseAU/SwiftJWW/issues/22)).
- **Values that are not dimensions stay text.** A radius, diameter or angle value, a value in another
  unit, or a value with no arrow points at the stated distance is kept as a loose text and listed in
  `unexplainedDimensionValues` (the text as written, its position at full size and its layer), with
  an `unexplainedDimensionValue` warning.
- **Stored dimension records.** A drawing made with Jw_cad's dimension command stores each
  dimension as one record. In a file of version 4.20 or later the record has its measured points
  and comes back as a `.dimension`, not listed as rebuilt, with no edges on the shapes path. In an older file it has none, so SwiftJWW
  writes its line and value as a loose line and text; its value is listed in
  `unexplainedDimensionValues` with a warning, as above.

Limits: SwiftJWW rebuilds dimensions from top-level elements only, so loose dimension pieces inside
a block stay pieces, with no warning, and an older dimension record inside a block is not listed.
A solid fill at the top level is skipped by SwiftJWW and reported as `skippedEntities` of type
`SOLID`, with no layer; one inside a block is dropped by SwiftJWW without being counted, so it is
not reported ([SwiftJWW#24](https://github.com/SecondMouseAU/SwiftJWW/issues/24)). The members of an expanded block keep their own layer names
but are scaled by the layer group of the reference that places them, so `layerNamePrefix` gives a
member's scale only when both are in the same group. A JWW declares no length unit, so it has the
`unitsNotDeclared` warning; Jw_cad draws in millimetres.

## `DrawingWarning`

What a read dropped or assumed, as data. Each has a `kind`, and where they concern one, a `type`,
a `layer` and a `count`, and a `message`.

| Kind | Meaning |
|---|---|
| `skippedEntities` | Entities of a type with no entity form were not read, by type and layer. `layer` is `nil` for a DWG, which does not tell it. |
| `unreadable` | The reader found something it could not read, so it is not in the drawing: an entity, a table record or a block, by `type` (`LINE`, `LAYER`, `BLOCK_RECORD`, `OBJECT` for one with no readable type). A DWG only; counts once for each reference that expanded the block; blocks left unexpanded are counted too. |
| `paperSpaceEntities` | Entities flagged as paper space were read, or left out when asked. |
| `missingBlock`, `blockCycle`, `blockNestingTooDeep` | A reference names a block the file does not define; a block contains itself; nesting went past the limit. |
| `notTransformed`, `unsupportedExtrusion`, `extrusionNotApplied` | An entity a non-uniform scale could not carry was dropped; references with an extrusion not along z were expanded flat; entities with such an extrusion were read as if it were along z. |
| `expansionTruncated` | Block expansion stopped at its size limit. |
| `unitsNotDeclared` | The file declares no length unit. |
| `emptyDrawing` | Nothing was read. |
| `scaleNotStated` | A JWW layer group that holds part of the drawing states no usable scale, so it was read at drawn size. `layer` is the group's layer-name prefix (`0-`). |
| `mixedScales` | The JWW layer groups that hold the drawing have different scales; each is at its own full size. `count` is the number of different scales. |
| `unexplainedDimensionValue` | A JWW dimension value that is not a `.dimension` in the drawing (SwiftJWW could not pair it with arrow points, or its record stores no measured points); it stays a loose text. One per value, with its `layer`; the value and position are in `unexplainedDimensionValues`. |

The `unreadable` kind reads the names SwiftDWG documents in its README: the `UNREADABLE_` prefix, and
`LAYER`, `LTYPE`, `STYLE`, `DIMSTYLE` and `BLOCK_RECORD` as the tables whose records it counts.
SwiftDWG does not export them, so `Sources/OCCTSwiftIO/Drawing/DrawingLoader+Skipped.swift` holds a
copy: check it against SwiftDWG's README when moving to a new release. A table it does not know is
worded as entities.
