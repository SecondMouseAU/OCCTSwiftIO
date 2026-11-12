# dwg2dxf

Converts a DWG drawing to ASCII DXF. `DWGLoader` in OCCTSwiftIO runs this tool and reads its
output with SwiftDXF, so DWG support costs the Swift package no new dependency.

## Build and install

```bash
cd Tools/dwg2dxf
cargo build --release
# then either put it on PATH, or point OCCTSwiftIO at it:
export OCCTSWIFTIO_DWG2DXF="$PWD/target/release/dwg2dxf"
```

## Use

```bash
dwg2dxf drawing.dwg drawing.dxf    # to a file
dwg2dxf drawing.dwg -              # to standard output
dwg2dxf --version                  # dwg2dxf 0.1.0 acadrust 0.6.8
```

## What reads the DWG

[acadrust](https://github.com/hakanaktt/acadrust), pinned exactly to 0.6.8. It reads AC1009
(R11/R12) through AC1032 (2018 and later). The pin is exact because a conversion is only
reproducible if the converter is.

## Licence

acadrust is MPL-2.0. This tool links it unmodified, which MPL-2.0 permits alongside this
repository's LGPL-2.1 code: MPL-2.0 is file-level copyleft and covers only acadrust's own files.
LibreDWG (GPL-3.0) was considered and not used.
