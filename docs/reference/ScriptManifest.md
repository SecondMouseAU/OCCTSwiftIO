---
title: ScriptManifest
parent: API Reference
---

# ScriptManifest

`ScriptManifest` is the JSON document a script harness writes to describe a scene: a versioned list of
bodies, each pointing at a sibling BREP file with optional color and PBR material hints. It is a pure
`Codable`, `Sendable` value type — decoding it does **not** require linking OCCT. Load it together with
its bodies via [`ShapeLoader.loadFromManifest(at:)`](ShapeLoader.md#shapeloaderloadfrommanifestat).

## Topics

- [`ScriptManifest`](#scriptmanifest-1) · [`ScriptManifest.BodyDescriptor`](#scriptmanifestbodydescriptor) · [`ScriptManifest.ManifestMetadata`](#scriptmanifestmanifestmetadata)

---

## `ScriptManifest`

```swift
public struct ScriptManifest: Codable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let description: String?
    public let bodies: [BodyDescriptor]
    public let metadata: ManifestMetadata?
}
```

- `version` — manifest schema version.
- `timestamp` — when the manifest was written (ISO-8601 in JSON).
- `description` — optional free-text scene description.
- `bodies` — the body descriptors (see below).
- `metadata` — optional document-level metadata.

---

## `ScriptManifest.BodyDescriptor`

One body: a reference to a BREP file plus optional appearance hints.

```swift
public struct BodyDescriptor: Codable, Sendable {
    public let id: String?
    public let file: String       // resolved relative to the manifest's directory
    public let format: String
    public let name: String?
    public let roughness: Float?
    public let metallic: Float?

    /// Color decoded from a `[r, g, b, a]` JSON array under the key "color".
    public var color: SIMD4<Float>? { get }
}
```

- `file` — the sibling geometry file, resolved relative to the manifest's directory by
  `loadFromManifest`.
- `color` — a computed accessor: returns the `[r, g, b, a]` JSON array (key `"color"`) as a
  `SIMD4<Float>`, or `nil` when absent or shorter than four elements.
- `roughness` / `metallic` — optional PBR material hints.

---

## `ScriptManifest.ManifestMetadata`

Document-level metadata.

```swift
public struct ManifestMetadata: Codable, Sendable {
    public let name: String
    public let revision: String?
    public let dateCreated: Date?
    public let dateModified: Date?
    public let source: String?
    public let tags: [String]?
    public let notes: String?
}
```

- **Example:**
  ```swift
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  let manifest = try decoder.decode(ScriptManifest.self, from: jsonData)
  print(manifest.metadata?.name ?? "", manifest.bodies.count)
  ```
