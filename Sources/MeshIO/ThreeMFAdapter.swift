import Foundation
import ThreeMF

extension MeshIO {

    /// Read a **3MF** package into a ``Mesh`` via the ThreeMF package. Uses ThreeMF's flattened
    /// `LoadedModel` — build items expanded into mesh instances with accumulated transforms — so
    /// multi-object / instanced models are placed correctly.
    static func readThreeMF(data: Data, weldEpsilon: Float) throws -> Mesh {
        let loaded = try runBlocking { try await ThreeMF.ModelLoader(data: data).load() }

        var soup: [SIMD3<Float>] = []
        func emit(_ mesh: ThreeMF.Mesh, _ transforms: [Matrix3D]) {
            let vs = mesh.vertices.map { v -> SIMD3<Double> in placed(SIMD3(v.x, v.y, v.z), transforms) }
            for t in mesh.triangles {
                let a = vs[t.v1], b = vs[t.v2], c = vs[t.v3]
                soup.append(SIMD3(Float(a.x), Float(a.y), Float(a.z)))
                soup.append(SIMD3(Float(b.x), Float(b.y), Float(b.z)))
                soup.append(SIMD3(Float(c.x), Float(c.y), Float(c.z)))
            }
        }

        for item in loaded.items {
            for comp in item.components where comp.meshIndex < loaded.meshes.count {
                emit(loaded.meshes[comp.meshIndex].mesh, comp.transforms)
            }
        }
        // Fallback: a model with meshes but no resolved build items — emit them untransformed.
        if soup.isEmpty {
            for lm in loaded.meshes { emit(lm.mesh, []) }
        }
        guard !soup.isEmpty else { throw MeshError.notRecognized }
        return weldEpsilon > 0 ? Mesh.welded(soup, epsilon: weldEpsilon) : Mesh.indexedSoup(soup)
    }

    /// Write a ``Mesh`` as a single-object **3MF** package via ThreeMF.
    static func writeThreeMF(_ mesh: Mesh) throws -> Data {
        let verts = mesh.positions.map { ThreeMF.Mesh.Vertex(x: Double($0.x), y: Double($0.y), z: Double($0.z)) }
        let tris = (0..<mesh.triangleCount).map { t -> ThreeMF.Mesh.Triangle in
            let (a, b, c) = mesh.triangle(t)
            return ThreeMF.Mesh.Triangle(v1: Int(a), v2: Int(b), v3: Int(c), propertyIndex: nil)
        }
        let object = ThreeMF.Object(id: 1, content: .mesh(ThreeMF.Mesh(vertices: verts, triangles: tris)))
        let model = ThreeMF.Model(resources: [object], build: ThreeMF.Build(items: [ThreeMF.Item(objectID: 1)]))
        let writer = ThreeMF.PackageWriter<Data>()
        writer.model = model
        return try writer.finalize()
    }

    /// Apply a 3MF transform chain (parent→child) to a point. Each `Matrix3D` is a 4×3 row-major
    /// affine (rows 0–2 = linear part, row 3 = translation); child-most transform applies first.
    private static func placed(_ p0: SIMD3<Double>, _ transforms: [Matrix3D]) -> SIMD3<Double> {
        var p = p0
        for m in transforms.reversed() {
            let v = m.values
            p = SIMD3(
                p.x * v[0][0] + p.y * v[1][0] + p.z * v[2][0] + v[3][0],
                p.x * v[0][1] + p.y * v[1][1] + p.z * v[2][1] + v[3][1],
                p.x * v[0][2] + p.y * v[1][2] + p.z * v[2][2] + v[3][2]
            )
        }
        return p
    }

    /// Run an async operation to completion from a synchronous context. ThreeMF's loader is async
    /// (it unzips + resolves referenced model parts); MeshIO's `load` API is synchronous.
    private static func runBlocking<T: Sendable>(_ op: @Sendable @escaping () async throws -> T) throws -> T {
        let box = ResultBox<T>()
        let sem = DispatchSemaphore(value: 0)
        Task.detached {
            do { box.result = .success(try await op()) } catch { box.result = .failure(error) }
            sem.signal()
        }
        sem.wait()
        return try box.result!.get()
    }
}

private final class ResultBox<T>: @unchecked Sendable { var result: Result<T, Error>? }
