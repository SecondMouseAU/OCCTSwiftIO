---
title: Progress reporting
parent: Cookbook
nav_order: 5
---

# Progress reporting & cancellation

STEP and IGES imports can be slow on large assemblies. `ShapeLoader.load` / `loadRobust` accept an
optional `progress` observer conforming to OCCTSwift's `ImportProgress` protocol. `OCCTSwiftIO` ships
`ImportProgressClosure` so you can pass a closure instead of writing a one-shot subclass.

(STL / OBJ / BREP loaders are single-call upstream and do not surface progress; the observer is
honoured for STEP and IGES.)

## Closure-based progress

```swift
import OCCTSwift
import OCCTSwiftIO

let result = try await ShapeLoader.load(
    from: stepURL,
    format: .step,
    progress: ImportProgressClosure { fraction, step in
        print("\(Int(fraction * 100))% — \(step)")   // fraction in 0.0...1.0
    }
)
```

`fraction` runs `0.0...1.0`; `step` is a human-readable stage name (e.g. `"Reading STEP file"`).

## Threading note

The callback fires on whatever thread the importer runs on — typically a background thread, since
`ShapeLoader.load` dispatches the work off a `Task.detached`. Hop to the main actor for UI updates:

```swift
progress: ImportProgressClosure { fraction, _ in
    Task { @MainActor in progressBar.doubleValue = fraction }
}
```

## Cancellation

Pass a `cancelCheck` that returns `true` to cooperatively cancel. Wiring it to `Task.isCancelled` ties
the import to Swift structured-concurrency cancellation; cancelling throws `ImportError.cancelled`:

```swift
progress: ImportProgressClosure(
    cancelCheck: { Task.isCancelled },
    progress: { fraction, step in /* … */ }
)
```

The `ImportProgressClosure` initializer signature:

```swift
public init(
    cancelCheck: @escaping @Sendable () -> Bool = { false },
    progress: @escaping @Sendable (Double, String) -> Void
)
```
