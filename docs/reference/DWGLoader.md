---
title: DWGLoader
parent: API Reference
---

# DWGLoader

Reads DWG, AutoCAD's native drawing format, into the same SwiftDXF entity model
`DXFLoader.readEntities` returns. The reading is done by
[SwiftDWG](https://github.com/SecondMouseAU/SwiftDWG), a Swift reader that runs in process: there is
no tool to build, no subprocess and no environment variable, and it is not limited to macOS.

`import OCCTSwiftIO` also brings SwiftDWG's `DWG` namespace into scope (`DWG.Error`, `DWG.Version`,
`DWG.read`), as it does SwiftDXF's `DXF`. To read any of DXF, DWG and JWW through one call, use
`DrawingLoader.read(from:options:)`.

## `DWGLoader.readEntities(from:options:)`

```swift
public static func readEntities(
    from url: URL, options: DXF.ReadOptions = .init()
) throws -> Conversion
```

- **Parameters:** `url`, the DWG file. `options`, SwiftDXF's block-reference and paper-space options.
- **Returns:** a `Conversion`.
- **Throws:** `DWG.Error`: `.notADWG` (the bytes do not start like a DWG), `.unsupportedVersion`
  (a release SwiftDWG does not read), `.truncated` or `.invalid` (damage to the file's structure,
  which includes a layer, line type, text style, dimension style or block table whose control
  object cannot be read). An entity or table record that cannot be read does not throw: it is left
  out and reported in `warnings`.
- **Example:**
  ```swift
  do {
      let conversion = try DWGLoader.readEntities(from: dwgURL)
      for entity in conversion.drawing.entities { /* same cases as a DXF read */ }
      print(conversion.sourceVersion)   // AC1032
  } catch let error as DWG.Error {
      print(error)                      // "DWG version AC1009 is not supported"
  }
  ```

## `DWGLoader.Conversion`

```swift
public struct Conversion: Sendable {
    public let drawing: DXF.Drawing
    public let sourceSHA256: String    // lowercase hex
    public let sourceVersion: String   // DWG version code, e.g. AC1032
    public let warnings: [String]
}
```

Each read records the bytes it came from, so a drawing can be traced back to them. `warnings` has one
line for each type of entity or record the reader could not read, and one for a result with no
entities. `DrawingLoader` reports those two as data, in `DrawingWarning` (`.unreadable`,
`.emptyDrawing`), and the entities with no entity form as `.skippedEntities`; here they are in
`drawing.skipped`.

## Supported DWG versions

What SwiftDWG reads, from its README: R2000 to R2018 (`AC1015`, `AC1018`, `AC1021`, `AC1024`,
`AC1027`, `AC1032`), checked against AutoCAD's own DXF of the same drawings. R14 (`AC1014`) is read
for simple entities. R13 is written and has never been run, and R12 and earlier are not read:
`DWG.Error.unsupportedVersion`.

What survives is what SwiftDXF models, so a DWG gives the same entity cases as a DXF. Entity types
SwiftDXF does not model, and polyface and polygon meshes and the attributes of an insert, are counted
as skipped.

## Limits that matter to a caller

- **Unreadable records.** An entity SwiftDWG cannot read is left out and counted; a table record
  (layer, line type, text style, dimension style) or block it cannot read is left out and counted,
  and entities on a lost layer read as layer `0`. `DrawingLoader` reports each as a
  `DrawingWarning` of kind `.unreadable`.
- **Skipped entities carry no layer.** SwiftDWG writes the entities it does not model, and the ones it
  could not read, as bare records, so SwiftDXF counts them on layer `0` (on the layer of the `INSERT`
  in a block that was expanded), whatever their layer was. `DrawingWarning.layer` is `nil` for a DWG.
- **Some damage crashes or stalls the reader instead of throwing.** A truncated file, a wrong
  version and a file that is not a DWG throw `DWG.Error`. But in SwiftDWG 0.1.0 a changed byte
  inside the compressed data of the AC1027 and AC1032 files tried can trap (a negative range in its
  decompression), and a changed byte in the section map at the end of the file can keep it running
  for more than 20 seconds with memory growing. Do not read DWGs you do not trust in a process you
  cannot afford to lose.
- **Splines** that AutoCAD stored as fit points only come back with fit points and no control points.
- **Leader hook lines** have the vertices the DWG holds, not the extra vertex AutoCAD adds in its DXF.
- **Entities after an unreadable one, before R2004.** Each names the next, so those after one that
  cannot be read are lost with it and counted as one.
- **Text before R2007** is decoded from the code pages SwiftDWG has a table for and read as
  Windows-1252 otherwise, so text in another code page can come out wrong.
- Anonymous block names keep their DWG numbers; AutoCAD's DXF renumbers them. Performance has not
  been measured.

## Licence and credits

SwiftDWG is MIT. It is a Swift port of the DWG reader in [ACadSharp](https://github.com/DomCR/ACadSharp)
(MIT) together with the Open Design Alliance's published specification of the format; it says so, and
is not a clean-room implementation. Its `NOTICE.md` has the acknowledgements and the ACadSharp licence
text. LibreDWG (GPL) is not used.
