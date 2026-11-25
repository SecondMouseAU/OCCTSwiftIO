import Foundation
import Testing

@testable import MeshIO

/// The shared `Mesh.init(positions:indices:weldEpsilon:)` that OBJ and PLY read through (#30).
@Suite("Mesh weld initialiser")
struct MeshWeldInitTests {

    typealias Fixture = MeshWeldCharacterizationTests

    static let stored = Fixture.stored
    static let storedIndices: [UInt32] = Fixture.storedFaces.flatMap { $0.map { UInt32($0) } }

    @Test("it gives what the readers give, at each epsilon")
    func t_matchesTheReaders() {
        #expect(
            Mesh(positions: Self.stored, indices: Self.storedIndices, weldEpsilon: 1e-4)
                == Fixture.weldedDefault)
        #expect(
            Mesh(positions: Self.stored, indices: Self.storedIndices, weldEpsilon: 0.01)
                == Fixture.weldedCoarse)
        #expect(
            Mesh(positions: Self.stored, indices: Self.storedIndices, weldEpsilon: 0)
                == Fixture.unwelded)
    }

    @Test("with no welding the arrays are kept as given, unused and duplicate vertices included")
    func t_noWeldKeepsTheArrays() {
        let positions = [Fixture.p0, Fixture.p0, Fixture.p5]
        let indices: [UInt32] = [0, 1, 0]
        let mesh = Mesh(positions: positions, indices: indices, weldEpsilon: 0)
        #expect(mesh.positions == positions)
        #expect(mesh.indices == indices)
    }

    @Test("a soup indexed 0..<n welds and indexes as the glTF and 3MF readers do")
    func t_identityIndexedSoupMatchesTheSoupHelpers() {
        // glTF and 3MF build a soup and call `welded` or `indexedSoup` directly. Routing them
        // through this initialiser would give the same meshes, but costs an index array and a
        // second copy of the soup for no gain, so they were left as they are.
        let soup = [Fixture.p0, Fixture.p1, Fixture.p2, Fixture.p0, Fixture.p2, Fixture.p3]
        let identity = (0..<UInt32(soup.count)).map { $0 }
        #expect(
            Mesh(positions: soup, indices: identity, weldEpsilon: 1e-4)
                == Mesh.welded(soup, epsilon: 1e-4))
        #expect(
            Mesh(positions: soup, indices: identity, weldEpsilon: 0) == Mesh.indexedSoup(soup))
    }

    @Test("a mesh with no triangles stays empty")
    func t_emptyIndices() {
        #expect(Mesh(positions: Self.stored, indices: [], weldEpsilon: 1e-4) == Mesh())
        #expect(
            Mesh(positions: Self.stored, indices: [], weldEpsilon: 0)
                == Mesh(positions: Self.stored, indices: []))
    }
}
