import Foundation

/// One contiguous run of `Mesh.indices` belonging to a single source-format material — the source
/// format's own segmentation of the face buffer, so a single part can be isolated from a whole-model
/// mesh. Empty for formats that carry no such grouping (STL, OBJ, PLY, ...).
public struct Submesh: Equatable, Sendable {
    /// Start of this run in `Mesh.indices`.
    public var indexOffset: Int
    /// Length of this run (always a multiple of 3).
    public var indexCount: Int
    /// Index into the source file's material list (0-based, file order).
    public var materialIndex: Int

    public init(indexOffset: Int, indexCount: Int, materialIndex: Int) {
        self.indexOffset = indexOffset
        self.indexCount = indexCount
        self.materialIndex = materialIndex
    }
}

/// A welded, indexed triangle mesh — the neutral currency of ``MeshIO``. Positions are unique;
/// `indices` holds three vertex indices per triangle. Pure value type, no OCCT.
public struct Mesh: Equatable, Sendable {
    public var positions: [SIMD3<Float>]
    public var indices: [UInt32]
    /// Per-material index ranges, in source file order. Empty for formats/files with no such grouping.
    public var submeshes: [Submesh]

    public init(positions: [SIMD3<Float>] = [], indices: [UInt32] = [], submeshes: [Submesh] = []) {
        self.positions = positions
        self.indices = indices
        self.submeshes = submeshes
    }

    public var vertexCount: Int { positions.count }
    public var triangleCount: Int { indices.count / 3 }

    public func triangle(_ t: Int) -> (UInt32, UInt32, UInt32) {
        (indices[t * 3], indices[t * 3 + 1], indices[t * 3 + 2])
    }
    public func trianglePositions(_ t: Int) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
        let (a, b, c) = triangle(t)
        return (positions[Int(a)], positions[Int(b)], positions[Int(c)])
    }

    public var bounds: (min: SIMD3<Float>, max: SIMD3<Float>)? {
        guard var lo = positions.first else { return nil }
        var hi = lo
        for p in positions {
            lo = SIMD3(min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z))
            hi = SIMD3(max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z))
        }
        return (lo, hi)
    }

    /// Merge coincident vertices by quantizing positions to a grid of size `epsilon`. Used to restore
    /// connectivity in formats that split vertices at seams (STL has none; OBJ/PLY/source formats may).
    public static func welded(_ soup: [SIMD3<Float>], epsilon: Float) -> Mesh {
        let inv = 1.0 / Swift.max(epsilon, .leastNormalMagnitude)
        var map = [SIMD3<Int32>: UInt32](minimumCapacity: soup.count / 2)
        var positions = [SIMD3<Float>](); positions.reserveCapacity(soup.count / 2)
        var indices = [UInt32](); indices.reserveCapacity(soup.count)
        for v in soup {
            let key = SIMD3<Int32>(Int32((v.x * inv).rounded()), Int32((v.y * inv).rounded()), Int32((v.z * inv).rounded()))
            if let i = map[key] { indices.append(i) }
            else { let i = UInt32(positions.count); map[key] = i; positions.append(v); indices.append(i) }
        }
        return Mesh(positions: positions, indices: indices)
    }

    /// Index a triangle soup without welding (each corner becomes its own vertex).
    public static func indexedSoup(_ soup: [SIMD3<Float>]) -> Mesh {
        Mesh(positions: soup, indices: (0..<UInt32(soup.count)).map { $0 })
    }
}
