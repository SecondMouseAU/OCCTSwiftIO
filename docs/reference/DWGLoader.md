---
title: DWGLoader
parent: API Reference
---

# DWGLoader

Reads DWG, AutoCAD's native drawing format, into the same SwiftDXF entity model
`DXFLoader.readEntities` returns. DWG is a closed binary format with no Swift reader, so the
reading is done by the `dwg2dxf` tool in `Tools/dwg2dxf`, which this loader runs as a subprocess
and whose DXF output it parses with SwiftDXF. The Swift package gains no dependency.

macOS only. Other platforms throw `DWGError.unsupportedPlatform`.

## Setup

```bash
cd Tools/dwg2dxf
cargo build --release
export OCCTSWIFTIO_DWG2DXF="$PWD/target/release/dwg2dxf"   # or put it on PATH
```

## `DWGLoader.readEntities(from:converter:)`

```swift
public static func readEntities(from url: URL, converter: URL? = nil) throws -> Conversion
```

- **Parameters:** `url`, the DWG file. `converter`, the `dwg2dxf` executable; when `nil` it is
  taken from `OCCTSWIFTIO_DWG2DXF`, then looked for on `PATH`.
- **Returns:** a `Conversion`.
- **Throws:** `DWGError.converterNotFound`, `.notADWG` (the file does not start with a DWG version
  code), `.conversionFailed` (the tool ran and failed), `.unsupportedPlatform`, or a SwiftDXF read
  error.
- **Example:**
  ```swift
  let conversion = try DWGLoader.readEntities(from: dwgURL)
  for entity in conversion.drawing.entities { /* same cases as a DXF read */ }
  print(conversion.sourceVersion, conversion.converter)   // AC1032  dwg2dxf 0.1.0 acadrust 0.6.8
  ```

## `DWGLoader.Conversion`

```swift
public struct Conversion: Sendable {
    public let drawing: DXF.Drawing
    public let converter: String       // the tool's --version line
    public let sourceSHA256: String    // lowercase hex
    public let sourceVersion: String   // DWG version code, e.g. AC1032
    public let warnings: [String]
}
```

A conversion is a step someone may later have to account for, so each one records what was
converted and what converted it. `warnings` carries anything a caller should not miss, such as a
result with no recognised entities.

## `DWGLoader.locateConverter(explicit:)`

```swift
public static func locateConverter(explicit: URL? = nil) -> URL?
```

Returns the executable that would be used, or `nil` when none is found. An `explicit` URL that is
not executable returns `nil`; it does not fall back to the environment.

## Supported DWG versions

Whatever the pinned acadrust reads: AC1009 (R11/R12) through AC1032 (2018 and later). What survives
is what SwiftDXF then reads from the converted DXF, so `INSERT`, `HATCH` and `LEADER` are dropped
the same way they are for a native DXF.

## Licence

acadrust is MPL-2.0. `dwg2dxf` links it unmodified and is a separate executable. LibreDWG (GPL-3.0)
was considered and not used.
