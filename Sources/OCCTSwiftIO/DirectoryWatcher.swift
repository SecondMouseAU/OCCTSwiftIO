// DirectoryWatcher.swift
// OCCTSwiftIO
//
// kqueue-backed file/directory change notifications. Ported from OCCTSwiftViewport's
// Examples/MetalDemo/Sources/OCCTSwiftMetalDemo/ScriptWatcher.swift, the only existing
// implementation of this technique anywhere in the ecosystem, into a standalone public type
// with no Viewport dependency. macOS-only: kqueue is a Darwin primitive and this package's
// platform floor also spans iOS/visionOS/tvOS, so the whole file is gated #if os(macOS).

#if os(macOS)
    import Dispatch
    import Foundation

    /// Watches a file or directory for create/modify events and invokes a caller-supplied
    /// closure when one occurs.
    ///
    /// See `docs/reference/DirectoryWatcher.md` for the full behavior writeup and an example.
    public final class DirectoryWatcher: @unchecked Sendable {

        /// Invoked when a relevant change is observed.
        ///
        /// Fires on `queue`.
        public typealias ChangeHandler = @Sendable () -> Void

        /// The file or directory being watched.
        public let url: URL

        private let path: String
        private let queue: DispatchQueue
        private let onChange: ChangeHandler

        private let lock = NSLock()
        private var directSource: DispatchSourceFileSystemObject?
        private var fallbackSource: DispatchSourceFileSystemObject?
        private var lastEntryStamps: [String: EntryStamp] = [:]
        private var started = false

        private struct EntryStamp: Equatable {
            var modificationDate: Date?
            var size: Int
        }

        /// - Parameters:
        ///   - url: the file or directory to watch. May not exist yet.
        ///   - queue: the queue event handling runs on. Defaults to a private serial queue so
        ///     callers don't need to reason about reentrancy.
        ///   - onChange: called when a relevant change is observed.
        public init(
            url: URL,
            queue: DispatchQueue = DispatchQueue(
                label: "com.secondmouseau.occtswiftio.directory-watcher"),
            onChange: @escaping ChangeHandler
        ) {
            self.url = url
            self.path = url.path
            self.queue = queue
            self.onChange = onChange
        }

        deinit {
            stop()
        }

        /// Begins watching.
        ///
        /// Safe to call on a path that does not exist yet; watching begins once it is
        /// created. A second call while already started is a no-op.
        public func start() {
            lock.lock()
            guard !started else {
                lock.unlock()
                return
            }
            started = true
            _ = attemptDirectAttach()
            lock.unlock()
        }

        /// Stops watching and releases the kqueue file descriptor(s).
        ///
        /// Safe to call more than once, and safe to call from `deinit`.
        public func stop() {
            lock.lock()
            guard started else {
                lock.unlock()
                return
            }
            started = false
            directSource?.cancel()
            directSource = nil
            fallbackSource?.cancel()
            fallbackSource = nil
            lastEntryStamps = [:]
            lock.unlock()
        }

        // MARK: - Attachment (callers must hold `lock`)

        /// Tries to open `path` directly, watching its containing directory's entries (with
        /// dotfiles filtered) if it is a directory, or the file itself otherwise.
        ///
        /// Falls back to watching the nearest existing ancestor directory when `path` doesn't
        /// exist yet.
        ///
        /// - Parameter treatCreationAsChange: when `true`, finding anything already at `path`
        ///   (a non-empty directory, or any file at all) is itself reported as a change. Set by
        ///   the fallback-to-direct promotion, where `path` is known to have just come into
        ///   existence; left `false` for `start()`'s own initial attach, which only establishes a
        ///   baseline and must not fire just because the watched path already had content.
        ///
        ///   An empty directory, though, does NOT fire even with `treatCreationAsChange: true`:
        ///   a bare `mkdir` is deliberately not itself a reportable change here, only content
        ///   appearing inside it is. This is intentional, not an oversight: every real consumer
        ///   of this type watches for a FILE landing inside a directory (`selection.json`, a
        ///   `highlight_requests/<id>.json`), never for the directory's own bare existence, and
        ///   the subsequent write that adds the first real entry already fires on its own via
        ///   the ordinary entry-diff path. Revisit if a future consumer genuinely needs "the
        ///   directory now exists, even empty" as a distinct signal.
        /// - Returns: whether the caller should invoke `onChange` after unlocking.
        private func attemptDirectAttach(treatCreationAsChange: Bool = false) -> Bool {
            fallbackSource?.cancel()
            fallbackSource = nil
            directSource?.cancel()
            directSource = nil

            var isDirectoryRef: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectoryRef)
            guard exists else {
                return attachFallback()
            }

            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else {
                return attachFallback()
            }

            let isDirectory = isDirectoryRef.boolValue
            let fireNow: Bool
            if isDirectory {
                let snapshot = Self.snapshotNonDotfileEntries(ofDirectory: path)
                fireNow = treatCreationAsChange && !snapshot.isEmpty
                lastEntryStamps = snapshot
            } else {
                fireNow = treatCreationAsChange
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .attrib, .link, .rename, .delete, .revoke],
                queue: queue
            )
            source.setEventHandler { [weak self, weak source] in
                let flags = source?.data ?? []
                self?.handleDirectEvent(isDirectory: isDirectory, flags: flags)
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            directSource = source

            return fireNow
        }

        /// Watches the nearest existing ancestor directory of `path` for a write, so we notice
        /// when `path` itself is created.
        ///
        /// - Returns: whether the caller should invoke `onChange` after unlocking, per
        ///   `attemptDirectAttach`'s own contract. Ordinarily `false` (arming a watch is not
        ///   itself an observed change), except when the closing re-check below catches up.
        @discardableResult
        private func attachFallback() -> Bool {
            let ancestor = Self.nearestExistingAncestor(of: path)
            let fd = open(ancestor, O_EVTONLY)
            guard fd >= 0 else {
                // Nothing left to fall back to (e.g. a permissions problem on the ancestor);
                // leave unwatched rather than crash. `start()` alone is a no-op once `started`
                // is already `true`, so recovering from this needs an explicit `stop()` then
                // `start()` to force a fresh attempt.
                return false
            }

            // `.delete`/`.rename` matter here too, not just `.write`: if the ancestor itself is
            // removed (e.g. `rm -rf out && mkdir -p out/a/b` on a still-missing `out`), a
            // write-only mask would never tell us, leaving this fd stale forever with no event
            // to trigger the re-resolution `handleFallbackEvent` already does on every callback.
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.handleFallbackEvent()
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            fallbackSource = source

            // Closes a TOCTOU race, not just tidiness: `path` (or an intermediate ancestor
            // closer to it) can come into existence in the gap between `nearestExistingAncestor`
            // resolving `ancestor` above and this kevent filter actually being armed by
            // `resume()`. kqueue only reports events that occur AFTER a filter is registered,
            // never ones that already happened, so a change landing in that gap would otherwise
            // go unobserved forever: nothing is pending on the freshly-armed fd, and nothing else
            // will prompt this watcher to look again. Re-checking once, synchronously, right
            // after arming, catches exactly that window; if it did close, this recurses into
            // `attemptDirectAttach` (which itself may recurse into `attachFallback` again, one
            // level closer, if only a partial ancestor appeared) rather than leaving the watch
            // sitting on a target that's already stale the instant it's armed. Bounded by the
            // number of path components between `ancestor` and `path`, not a loop: each
            // recursion only happens because the filesystem state genuinely changed since the
            // prior check.
            if FileManager.default.fileExists(atPath: path) {
                return attemptDirectAttach(treatCreationAsChange: true)
            }
            return false
        }

        // MARK: - Event handling

        private func handleDirectEvent(isDirectory: Bool, flags: DispatchSource.FileSystemEvent) {
            let shouldFire: Bool
            lock.lock()
            guard started else {
                lock.unlock()
                return
            }
            let identityInvalidated = flags.contains(.delete) || flags.contains(.rename)
            if isDirectory {
                let newStamps = Self.snapshotNonDotfileEntries(ofDirectory: path)
                let changed =
                    newStamps.count != lastEntryStamps.count
                    || newStamps.contains { name, stamp in lastEntryStamps[name] != stamp }
                lastEntryStamps = newStamps
                var fired = changed
                if identityInvalidated {
                    // The watched directory itself was deleted (or deleted and recreated,
                    // e.g. `rm -rf outputDir && mkdir outputDir`); reopen at the same path so
                    // a recreated directory keeps being watched under its new inode, rather
                    // than leaving the stale fd pointing at the unlinked one forever.
                    //
                    // `treatCreationAsChange: true`, and the result folded into `shouldFire`
                    // rather than discarded: `changed` above was computed from a snapshot taken
                    // BEFORE this reattach, so a delete-then-immediate-recreate-with-content
                    // landing between that snapshot and this call (both happen synchronously
                    // within this one callback) would otherwise have its content silently
                    // adopted as the new baseline with no notification ever firing for it.
                    fired = attemptDirectAttach(treatCreationAsChange: true) || fired
                }
                shouldFire = fired
            } else {
                shouldFire = true
                if identityInvalidated {
                    // The fd's underlying inode was replaced (e.g. an atomic write-then-rename
                    // over the watched path); reopen so future writes are still observed.
                    _ = attemptDirectAttach()
                }
            }
            lock.unlock()
            if shouldFire {
                onChange()
            }
        }

        private func handleFallbackEvent() {
            let shouldFire: Bool
            lock.lock()
            guard started else {
                lock.unlock()
                return
            }
            // Always retry, rather than checking whether the full `path` exists first: when
            // more than one path component is missing, this event means only the NEAREST
            // missing level just appeared (e.g. `root/a` created while `root/a/b/target.json`
            // is still the real target). `attemptDirectAttach` re-resolves the nearest existing
            // ancestor from scratch on failure, so this cascades one level closer each time an
            // intermediate directory is created, rather than getting stuck watching the
            // original, more distant ancestor forever.
            shouldFire = attemptDirectAttach(treatCreationAsChange: true)
            lock.unlock()
            if shouldFire {
                onChange()
            }
        }

        // MARK: - Helpers

        private static func snapshotNonDotfileEntries(ofDirectory path: String) -> [String:
            EntryStamp]
        {
            let fm = FileManager.default
            guard let names = try? fm.contentsOfDirectory(atPath: path) else { return [:] }
            var result: [String: EntryStamp] = [:]
            for name in names where !name.hasPrefix(".") {
                let fullPath = URL(fileURLWithPath: path).appendingPathComponent(name).path
                let attrs = try? fm.attributesOfItem(atPath: fullPath)
                result[name] = EntryStamp(
                    modificationDate: attrs?[.modificationDate] as? Date,
                    size: (attrs?[.size] as? NSNumber)?.intValue ?? 0
                )
            }
            return result
        }

        private static func nearestExistingAncestor(of path: String) -> String {
            let fm = FileManager.default
            var candidate = URL(fileURLWithPath: path).deletingLastPathComponent().path
            while !fm.fileExists(atPath: candidate) {
                let parent = URL(fileURLWithPath: candidate).deletingLastPathComponent().path
                if parent.isEmpty || parent == candidate {
                    return "/"
                }
                candidate = parent
            }
            return candidate
        }
    }
#endif
