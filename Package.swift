// swift-tools-version: 6.1

import PackageDescription
// Every dependency resolves from its published URL. NEVER from a `../<name>` sibling.
//
// The old helper preferred a sibling checkout when one existed, so the fleet would share the
// single OCCT.xcframework instead of each repo extracting its own (SecondMouseAU/ecosystem#8).
// The saving is real but bought in the wrong currency: a path dependency carries no version
// requirement, so SwiftPM compiles whatever happens to be checked out in that sibling and drops
// the pin from Package.resolved entirely. Committing that lockfile makes the repo unresolvable
// from any clean checkout, which is CI and every new clone.
//
// Not hypothetical: PadCAM's `main` was unresolvable for exactly this reason and nobody noticed,
// because everyone builds with siblings present. Four incidents in two days built stale sibling
// source (ecosystem#48), and four OCCTParts branches shipped a Package.resolved with every
// occtswift pin stripped, caught by a review bot reading the diff rather than by any check
// (ecosystem#51).
//
// Measured, which is what settles it: the artifact DOWNLOAD is already shared, in
// ~/Library/Caches/org.swift.swiftpm/artifacts, so a URL-resolved build reports
// "Fetched ... from cache" and touches no network. Sibling resolution only ever saved the
// per-project EXTRACTION, about 594 MB in .build/artifacts/. That is disk worth paying for a
// lockfile that means what it says, and it is separately recoverable by sharing the extraction
// (symlink or APFS clone) without substituting source at all.
//
// Ed's rule, 2026-08-20: nothing resolves locally except binaries, and the binary is already
// shared by the artifact cache. The helper is kept rather than reverted to a bare
// `.package(url:)` so the call sites stay identical across the fleet.
func occtDep(_ name: String, from version: String) -> Package.Dependency {
    .package(url: "https://github.com/SecondMouseAU/\(name).git", from: Version(version)!)
}
func meshDep(_ name: String, from version: String) -> Package.Dependency {
    .package(url: "https://github.com/SecondMouseAU/\(name).git", from: Version(version)!)
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
        occtDep("OCCTSwift", from: "3.0.0"),    // ≥3.0.0: Rule 2 major on a small surface (docs/SEMVER.md#v300); OCCT itself does not move, the kernel stays 8.0.1 rebuilt as v3.0.0-kernel.1 to carry two patches the v2.0.0 asset missed (OCCTSwift#905/#913). Three breaks, all compile errors: Selector.SubShapeType.compsolid renamed .compSolid, and Shape.ShapeFilterType.RawValue moving Int32 to Int as ShapeFilterType becomes a ShapeType typealias (both OCCTSwift#844), have zero hits in this repo; Shape.bounds/size/center, Wire.bounds, Edge.bounds and Face.bounds/exactBounds becoming Optional (OCCTSwift#943) is the one that bit. Audited every call site (OCCTSwiftIO#38): Sources never read those accessors, so the shipped library is unchanged; three test call sites did (DXFLoaderTests, JWWLoaderTests) and now unwrap through the `try #require` they already sat behind, not a default, because a void bounding box has to fail the assertion rather than read as a zero-size shape at the world origin. ≥2.0.0: correctness release (OCCTSwift#377/#669), OCCT absorbed to 8.0.1. 17 breaking changes (docs/SEMVER.md#v200); audited against every OCCTSwift call site in this repo (OCCTSwiftIO#34): none touch the changed sub-shape-enumeration/AAG/mass-property/continuity surfaces, so no source change was needed. ≥1.17.0: Pass 1a duplication/bug-fix audit (OCCTSwift#377/#380): continuity enum consolidation (source-compatible via deprecated aliases), Surface.drawMesh/evaluateGrid now return SurfaceGrid (not used here); ≥1.12.9: OCCT kernel crash/hang fixes through #318 and #323 (patches 0003-0009); multibody importers (#302)
        // Pure-Swift source-format readers (no OCCT), adapted by MeshIO.
        meshDep("SwiftPMX", from: "1.1.0"),     // PMX (MikuMikuDance): 1.1.0 adds Mesh.submeshes
        meshDep("SwiftX", from: "1.0.0"),       // DirectX .x
        meshDep("SwiftJWW", from: "1.2.1"),     // JWW (Jw_cad) 2D vector: used by OCCTSwiftIO, not MeshIO
        meshDep("SwiftDXF", from: "0.2.0"),     // DXF (AutoCAD) 2D vector: used by OCCTSwiftIO, not MeshIO
        .package(url: "https://github.com/tomasf/ThreeMF.git", from: "0.2.3"),   // 3MF read+write (MIT)
        .package(url: "https://github.com/schwa/SwiftGLTF.git", from: "1.0.2"),  // glTF/GLB read (BSD-3)
    ],
    targets: [
        // Pure-Swift 3D mesh formats: STL / OBJ / PLY native + PMX / .x via the standalone packages.
        // ZERO OCCT: importing MeshIO must not pull in the kernel.
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
            // virally, on MeshIO's importers, consistent with the ecosystem's existing Manifold C++ dep).
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
