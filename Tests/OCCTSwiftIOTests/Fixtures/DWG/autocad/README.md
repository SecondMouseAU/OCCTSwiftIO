# DWG files written by AutoCAD

Small drawings saved by AutoCAD, so the reader (SwiftDWG) is tested on files made by a program
that is not the one that wrote `plate.dwg` in the folder above (acadrust, a library that is
not used for reading any more).

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

## The pair

`point_object_id.dwg`, read through SwiftDWG, and AutoCAD's own `point_object_id.dxf` agree on the
layer, line type and dimension style tables (names and handles), the block names, the units and the
extents, and neither holds an entity. Both give the same kinds of warning (no length unit declared,
empty drawing). `DrawingLoaderTests` pins this.
