# DWG files written by AutoCAD

Two small drawings saved by AutoCAD 2025, so the reader is tested on files it did not write
itself (`plate.dwg` in the folder above is written by acadrust, the library that reads it).

| File | Version | Contents |
|---|---|---|
| `dimassoc-perpendicular.dwg` | AC1027 (AutoCAD 2013 format) | two lines (handles `2C1`, `2C2`) and a linear dimension (`2C3`) |
| `anonymous-names.dwg` | AC1032 (AutoCAD 2018 format) | five block definitions, three of them anonymous (`*U2`, `*U4`, `*U5`), each inserted once |

## Origin and licence

Both come from the [acadrust](https://github.com/hakanaktt/acadrust) repository, version 0.6.8
(`tests/fixtures/associative/dimassoc-perpendicular.dwg` and `tests/anonymous-names.dwg`). Its
author describes them as written by AutoCAD, synthetic, and containing no customer or third-party
content (`tests/fixtures/associative/README.md`, `tests/anonymous-names.md`), and licenses them
under the repository's MPL-2.0 licence: see `LICENSE-MPL-2.0` here. The two files are unmodified
copies. The rest of this repository is LGPL-2.1.

The contents the tests assert (line end points, the dimension's points, the handles and the block
names) are the ones that author documents for the files, not values read back from this reader.
