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
SwiftJWW and passed through its DXF writer.

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
}
```

`DrawingSource` records the file's `fileName`, its `sha256` (empty where CryptoKit is unavailable),
its `format` (`.dxf`, `.dwg`, `.jww`) and the format's own `version`: `$ACADVER` for a DXF and the
version code for a DWG (both like `AC1032`), the file version for a JWW (`700`).

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
