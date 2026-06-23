---
title: ImportProgressClosure
parent: API Reference
---

# ImportProgressClosure

`ImportProgressClosure` is a closure-backed conformance to OCCTSwift's `ImportProgress` protocol. It
lets you pass `progress:` to `ShapeLoader.load` / `loadRobust` as a closure instead of writing a
one-shot subclass. STEP and IGES imports fire the callbacks; other formats don't surface progress.

## Topics

- [`ImportProgressClosure.init(cancelCheck:progress:)`](#importprogressclosureinitcancelcheckprogress) · [`progress(fraction:step:)`](#progressfractionstep) · [`shouldCancel()`](#shouldcancel)

---

## `ImportProgressClosure.init(cancelCheck:progress:)`

Creates a progress observer from a progress closure and an optional cancellation closure.

```swift
public init(
    cancelCheck: @escaping @Sendable () -> Bool = { false },
    progress: @escaping @Sendable (Double, String) -> Void
)
```

- **Parameters:**
  - `cancelCheck` — return `true` to cooperatively cancel the import. Defaults to `{ false }`. Common
    pattern: `{ Task.isCancelled }` to wire upstream Swift-task cancellation.
  - `progress` — called with `fraction` in `0.0...1.0` and a human-readable step name (e.g. `"Reading
    STEP file"`).
- **Note:** callbacks fire on whatever thread the importer runs on (typically background when launched
  via the async `ShapeLoader.load`). Hop to the main actor for UI updates.
- **Example:**
  ```swift
  let result = try await ShapeLoader.load(
      from: stepURL, format: .step,
      progress: ImportProgressClosure(
          cancelCheck: { Task.isCancelled },
          progress: { fraction, step in
              Task { @MainActor in progressBar.doubleValue = fraction }
          }
      )
  )
  ```

---

## `progress(fraction:step:)`

`ImportProgress` protocol requirement; forwards to the stored progress closure.

```swift
public func progress(fraction: Double, step: String)
```

- **Parameters:** `fraction` — completion in `0.0...1.0`; `step` — the current stage name.

---

## `shouldCancel()`

`ImportProgress` protocol requirement; returns the result of the stored `cancelCheck` closure. When it
returns `true`, the loader throws `ImportError.cancelled`.

```swift
public func shouldCancel() -> Bool
```
