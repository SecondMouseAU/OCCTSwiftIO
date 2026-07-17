// swift-tools-version: 6.1

import PackageDescription
import Foundation

// Prefer a local sibling checkout (../<name>) when present on this machine, else the published URL.
// Local path deps let the whole OCCT ecosystem SHARE the single OCCTSwift/Libraries/OCCT.xcframework
// (1.3 GB) instead of each repo downloading + extracting its own copy. CI / fresh clones (no sibling)
// transparently use the URL pin. Detection is `#filePath`-relative so it's independent of build CWD.
// Use a local sibling checkout (../<name>) ONLY for top-level dev — never when this package is itself a
// resolved dependency (i.e. checked out under a consumer's `.build/`), where `../<name>` would point at a
// sibling checkout and create a path-vs-version identity conflict for that dependency.
func siblingOrURL(_ name: String, from version: String) -> Package.Dependency {
    let manifestDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
    if !manifestDir.contains("/.build/"),
       FileManager.default.fileExists(atPath: manifestDir + "/../\(name)/Package.swift") {
        return .package(path: "../\(name)")
    }
    return .package(url: "https://github.com/SecondMouseAU/\(name).git", from: Version(version)!)
}
func occtDep(_ name: String, from version: String) -> Package.Dependency { siblingOrURL(name, from: version) }
func meshDep(_ name: String, from version: String) -> Package.Dependency { siblingOrURL(name, from: version) }

let package = Package(
    name: "OCCTSwiftIO",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v1),
        .tvOS(.v18)
    ],
    products: [
        .library(
            name: "OCCTSwiftIO",
            targets: ["OCCTSwiftIO"]
        ),
        // Pure-Swift mesh I/O (no OCCT). The 3D-mesh formats live here so OCCT-free consumers (e.g. the
        // raw-mesh reconstruction ingest) can read them without dragging in the kernel.
        .library(
            name: "MeshIO",
            targets: ["MeshIO"]
        ),
    ],
    dependencies: [
        occtDep("OCCTSwift", from: "1.11.3"),   // robust importers split multibody files (OCCTSwift#302)
        // Pure-Swift source-format readers (no OCCT), adapted by MeshIO.
        meshDep("SwiftPMX", from: "1.1.0"),     // PMX (MikuMikuDance) — 1.1.0 adds Mesh.submeshes
        meshDep("SwiftX", from: "1.0.0"),       // DirectX .x
        meshDep("SwiftJWW", from: "1.2.1"),     // JWW (Jw_cad) 2D vector — used by OCCTSwiftIO, not MeshIO
        meshDep("SwiftDXF", from: "0.2.0"),     // DXF (AutoCAD) 2D vector — used by OCCTSwiftIO, not MeshIO
        .package(url: "https://github.com/tomasf/ThreeMF.git", from: "0.2.3"),   // 3MF read+write (MIT)
        .package(url: "https://github.com/schwa/SwiftGLTF.git", from: "1.0.2"),  // glTF/GLB read (BSD-3)
    ],
    targets: [
        // Pure-Swift 3D mesh formats: STL / OBJ / PLY native + PMX / .x via the standalone packages.
        // ZERO OCCT — importing MeshIO must not pull in the kernel.
        .target(
            name: "MeshIO",
            dependencies: [
                .product(name: "SwiftPMX", package: "SwiftPMX"),
                .product(name: "SwiftX", package: "SwiftX"),
                .product(name: "ThreeMF", package: "ThreeMF"),
                .product(name: "SwiftGLTF", package: "SwiftGLTF"),
            ],
            path: "Sources/MeshIO",
            // ThreeMF → Nodal → pugixml is C++; importing it requires C++ interop on this target (and,
            // virally, on MeshIO's importers — consistent with the ecosystem's existing Manifold C++ dep).
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .interoperabilityMode(.Cxx)
            ]
        ),
        .target(
            name: "OCCTSwiftIO",
            dependencies: [
                .product(name: "OCCTSwift", package: "OCCTSwift"),
                .product(name: "SwiftJWW", package: "SwiftJWW"),
                .product(name: "SwiftDXF", package: "SwiftDXF"),
                "MeshIO",
            ],
            path: "Sources/OCCTSwiftIO",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "MeshIOTests",
            dependencies: ["MeshIO"],
            path: "Tests/MeshIOTests",
            swiftSettings: [.interoperabilityMode(.Cxx)]   // viral: MeshIO pulls in ThreeMF's C++ (pugixml)
        ),
        .testTarget(
            name: "OCCTSwiftIOTests",
            dependencies: ["OCCTSwiftIO"],
            path: "Tests/OCCTSwiftIOTests"
        ),
    ]
)
