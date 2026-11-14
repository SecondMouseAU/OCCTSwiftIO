# DWG files written by AutoCAD

Small drawings saved by AutoCAD, so the reader is tested on files it did not write
itself (`plate.dwg` in the folder above is written by acadrust, the library that reads it).

| File | Version | Contents |
|---|---|---|
| `dimassoc-perpendicular.dwg` | AC1027 (AutoCAD 2013 format) | two lines (handles `2C1`, `2C2`) and a linear dimension (`2C3`) |
| `anonymous-names.dwg` | AC1032 (AutoCAD 2018 format) | five block definitions, three of them anonymous (`*U2`, `*U4`, `*U5`), each inserted once |
| `point_object_id.dwg` and `point_object_id.dxf` | AC1032 | a new drawing with a DATATABLE and no entities. The DWG and the DXF were both written by AutoCAD 2027 from the same database, so the DXF is what AutoCAD says the DWG holds |

## Origin and licence

Both come from the [acadrust](https://github.com/hakanaktt/acadrust) repository, version 0.6.8
(`tests/fixtures/associative/dimassoc-perpendicular.dwg`, `tests/anonymous-names.dwg`,
`tests/datatable/point_object_id.dwg` and `.dxf`). Its author describes them as written by AutoCAD
and containing no customer or third-party content (`tests/fixtures/associative/README.md`,
`tests/anonymous-names.md`, `tests/datatable/README.md`), and licenses them under the repository's
MPL-2.0 licence: see `LICENSE-MPL-2.0` here. The files are unmodified copies. The rest of this
repository is LGPL-2.1.

The contents the tests assert (line end points, the dimension's points, the handles and the block
names) are the ones that author documents for the files, not values read back from this reader.

## A difference between the pair

Reading `point_object_id.dwg` through `dwg2dxf` and reading AutoCAD's own `point_object_id.dxf`
agree on the linetype, text style, dimension style and block record tables, names and handles. They
differ in two places the tests do not pin: the layer `Defpoints` has handle `82` in AutoCAD's DXF
and `85` in the converted one, and the converted DXF has two more application ids
(`AcAecLayerStandard`, `AcCmTransparency`). Both come from the converter's library (acadrust 0.6.8),
not from this package.
