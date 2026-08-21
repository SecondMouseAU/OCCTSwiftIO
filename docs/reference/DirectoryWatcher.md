---
title: DirectoryWatcher
parent: API Reference
---

# DirectoryWatcher

`DirectoryWatcher` is a kqueue-backed watcher for a file or directory: it invokes a
caller-supplied closure when a create/modify event is observed. macOS-only (`#if os(macOS)`,
kqueue is a Darwin primitive); absent on iOS, visionOS, and tvOS.

Ported from `OCCTSwiftViewport`'s `Examples/MetalDemo/Sources/OCCTSwiftMetalDemo/ScriptWatcher.swift`
demo-app code into a standalone public type with no Viewport dependency, so headless consumers
(OCCTMCP, OCCTSwiftInteraction) can react to a changed sidecar file without polling on a fixed
timer. Closes [#42](https://github.com/SecondMouseAU/OCCTSwiftIO/issues/42).

## Topics

- [`DirectoryWatcher.init(url:queue:onChange:)`](#directorywatcheriniturlqueueonchange) · [`start()`](#start) · [`stop()`](#stop)

---

## `DirectoryWatcher.init(url:queue:onChange:)`

Creates a watcher for a file or directory. `url` may not exist yet.

```swift
public init(
    url: URL,
    queue: DispatchQueue = DispatchQueue(label: "com.secondmouseau.occtswiftio.directory-watcher"),
    onChange: @escaping ChangeHandler
)
```

- **Parameters:**
  - `url`: the file or directory to watch.
  - `queue`: the queue event handling runs on. Defaults to a private serial queue.
  - `onChange`: `() -> Void`, called when a relevant change is observed.

---

## `start()`

Begins watching.

```swift
public func start()
```

Safe to call on a path that does not exist yet: the watcher falls back to watching the nearest
existing ancestor directory, then switches to watching the target directly once it is created.
A second call while already started is a no-op.

When the watched path is a directory, dotfile entries (names starting with `.`) are ignored, so
a write-to-hidden-temp-name-then-rename-into-place sequence (`.incoming-x.json` renamed to
`x.json`) produces exactly one notification, for the final name.

---

## `stop()`

Stops watching and releases the kqueue file descriptor(s).

```swift
public func stop()
```

Safe to call more than once, and safe to call from `deinit` (which calls it automatically).

## Example

```swift
import OCCTSwiftIO

let watcher = DirectoryWatcher(url: outputDir) {
    reloadSceneFromDisk()
}
watcher.start()
// ...
watcher.stop()
```

`onChange` takes no arguments and fires on `queue`; a caller that needs to know what changed
re-inspects the watched path itself, rather than being told.
