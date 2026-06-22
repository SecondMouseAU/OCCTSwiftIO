---
title: The ScriptManifest format
parent: Cookbook
nav_order: 4
---

# The ScriptManifest format

A `ScriptManifest` is the JSON document a script harness writes to describe a scene: a list of bodies,
each pointing at a sibling BREP file, with optional color and PBR material hints. It is a pure
`Codable` value type — decoding it does **not** require linking OCCT.

## Loading a manifest + its BREP bodies

`ShapeLoader.loadFromManifest(at:)` decodes the manifest, then loads each `BodyDescriptor.file`
relative to the manifest's own directory (skipping any whose file is missing). Note this entry point
is synchronous `throws` (not `async`):

```swift
import OCCTSwift
import OCCTSwiftIO

let result = try ShapeLoader.loadFromManifest(at: manifestURL)   // .../manifest.json
for (shape, color) in result.shapesWithColors { /* … */ }

// The decoded manifest is preserved on the result:
if let manifest = result.manifest {
    print(manifest.description ?? "", manifest.bodies.count, "bodies")
}
```

## The shape of the document

```swift
public struct ScriptManifest: Codable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let description: String?
    public let bodies: [BodyDescriptor]
    public let metadata: ManifestMetadata?
}
```

Each body references a BREP file and carries optional appearance hints:

```swift
public struct BodyDescriptor: Codable, Sendable {
    public let id: String?
    public let file: String       // resolved relative to the manifest's directory
    public let format: String
    public let name: String?
    public let roughness: Float?
    public let metallic: Float?
    public var color: SIMD4<Float>?   // decoded from a [r, g, b, a] JSON array
}
```

`color` is stored in JSON as a four-element `[r, g, b, a]` array under the key `"color"` and surfaced
as a `SIMD4<Float>?` (nil when absent or shorter than four elements).

## Decoding manifest JSON yourself

`ScriptManifest` is plain `Codable`; the timestamp is ISO-8601. If you decode it directly (rather than
via `loadFromManifest`), configure the decoder accordingly:

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let manifest = try decoder.decode(ScriptManifest.self, from: jsonData)
```
