---
title: CADFileFormat
parent: API Reference
---

# CADFileFormat

`CADFileFormat` is the format selector consumed by `ShapeLoader`. It is a `String`-backed, `Sendable`
enum with one case per supported CAD/vector format and an initializer that maps a file extension to a
case.

## Topics

- [Cases](#cases) · [`CADFileFormat.init?(fileExtension:)`](#cadfileformatinitfileextension)

---

## Cases

```swift
public enum CADFileFormat: String, Sendable {
    case step
    case stl
    case obj
    case brep
    case iges
    /// JWW (Jw_cad) — a 2D vector drawing; loaded as a compound of OCCT edges (no B-Rep solid).
    case jww
}
```

`step`, `stl`, `obj`, `brep`, `iges` load to OCCT `Shape`s; `jww` loads to a compound of OCCT edges in
the `Z = 0` plane.

---

## `CADFileFormat.init?(fileExtension:)`

Maps a file extension (case-insensitive, no leading dot) to a format case, returning `nil` for an
unrecognised extension.

```swift
public init?(fileExtension ext: String)
```

- **Parameters:** `ext` — a path extension such as `"step"`, `"STP"`, `"iges"`.
- **Returns:** the matching `CADFileFormat`, or `nil` if the extension isn't recognised.
- **Recognised extensions:** `step`/`stp` → `.step`, `stl` → `.stl`, `obj` → `.obj`, `brep`/`brp` →
  `.brep`, `iges`/`igs` → `.iges`, `jww` → `.jww`.
- **Example:**
  ```swift
  let url = URL(fileURLWithPath: "part.STP")
  guard let format = CADFileFormat(fileExtension: url.pathExtension) else { return }
  let result = try await ShapeLoader.load(from: url, format: format)
  ```
