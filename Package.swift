// swift-tools-version: 6.1

import PackageDescription
import Foundation

// Prefer a local sibling checkout (../<name>) when present on this machine, else the published URL.
// Local path deps let the whole OCCT ecosystem SHARE the single OCCTSwift/Libraries/OCCT.xcframework
// (1.3 GB) instead of each repo downloading + extracting its own copy. CI / fresh clones (no sibling)
// transparently use the URL pin. Detection is `#filePath`-relative so it's independent of build CWD.
func occtDep(_ name: String, from version: String) -> Package.Dependency {
    let manifestDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
    if FileManager.default.fileExists(atPath: manifestDir + "/../\(name)/Package.swift") {
        return .package(path: "../\(name)")
    }
    return .package(url: "https://github.com/gsdali/\(name).git", from: Version(version)!)
}

// Same sibling-or-published rule, for the SecondMouseAU pure-Swift mesh-format readers consumed by MeshIO.
func meshDep(_ name: String, from version: String) -> Package.Dependency {
    let manifestDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
    if FileManager.default.fileExists(atPath: manifestDir + "/../\(name)/Package.swift") {
        return .package(path: "../\(name)")
    }
    return .package(url: "https://github.com/SecondMouseAU/\(name).git", from: Version(version)!)
}

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
        occtDep("OCCTSwift", from: "1.7.1"),
        // Pure-Swift source-format readers (no OCCT), adapted by MeshIO.
        meshDep("SwiftPMX", from: "1.0.0"),     // PMX (MikuMikuDance)
        meshDep("SwiftX", from: "1.0.0"),       // DirectX .x
    ],
    targets: [
        // Pure-Swift 3D mesh formats: STL / OBJ / PLY native + PMX / .x via the standalone packages.
        // ZERO OCCT — importing MeshIO must not pull in the kernel.
        .target(
            name: "MeshIO",
            dependencies: [
                .product(name: "SwiftPMX", package: "SwiftPMX"),
                .product(name: "SwiftX", package: "SwiftX"),
            ],
            path: "Sources/MeshIO",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "OCCTSwiftIO",
            dependencies: [
                .product(name: "OCCTSwift", package: "OCCTSwift"),
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
            path: "Tests/MeshIOTests"
        ),
        .testTarget(
            name: "OCCTSwiftIOTests",
            dependencies: ["OCCTSwiftIO"],
            path: "Tests/OCCTSwiftIOTests"
        ),
    ]
)
