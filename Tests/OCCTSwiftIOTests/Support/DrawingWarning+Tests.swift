@testable import OCCTSwiftIO

extension DrawingWarning {
    /// The kinds only the shapes path gives: what `DrawingLoader` says leaves them out.
    var isShapesPathOnly: Bool {
        kind == .noEdges || kind == .degenerate || kind == .notBuilt
    }
}
