// swift-tools-version: 6.1

import PackageDescription

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
        .package(url: "https://github.com/gsdali/OCCTSwift.git", from: "0.170.1"),
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
