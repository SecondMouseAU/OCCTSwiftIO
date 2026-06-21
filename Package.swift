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
    ],
    dependencies: [
        occtDep("OCCTSwift", from: "1.7.1"),
    ],
    targets: [
        .target(
            name: "OCCTSwiftIO",
            dependencies: [
                .product(name: "OCCTSwift", package: "OCCTSwift"),
            ],
            path: "Sources/OCCTSwiftIO",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "OCCTSwiftIOTests",
            dependencies: ["OCCTSwiftIO"],
            path: "Tests/OCCTSwiftIOTests"
        ),
    ]
)
