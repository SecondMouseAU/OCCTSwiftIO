#if os(macOS)
    import Foundation
    import Testing

    @testable import OCCTSwiftIO

    @Suite("DirectoryWatcher")
    struct DirectoryWatcherTests {

        /// Thread-safe change-notification counter for a watcher under test.
        private final class Recorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _count = 0

            func increment() {
                lock.lock()
                _count += 1
                lock.unlock()
            }

            var count: Int {
                lock.lock()
                defer { lock.unlock() }
                return _count
            }
        }

        /// Polls `condition` until it returns `true` or `timeout` elapses. kqueue notifications
        /// fire asynchronously on a background queue, so tests need a bounded wait rather than an
        /// immediate assertion right after triggering a filesystem change.
        private static func waitUntil(timeout: TimeInterval = 3.0, _ condition: () -> Bool) -> Bool
        {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if condition() { return true }
                Thread.sleep(forTimeInterval: 0.02)
            }
            return condition()
        }

        /// Waits until `recorder` reports no further changes for `quietPeriod` seconds, then
        /// returns its count.
        ///
        /// A more reliable settle than a fixed sleep: how long a delayed kqueue delivery takes
        /// to arrive varies with system load.
        private static func waitForStableCount(
            _ recorder: Recorder, quietPeriod: TimeInterval = 0.4, timeout: TimeInterval = 3.0
        ) -> Int {
            let deadline = Date().addingTimeInterval(timeout)
            var lastCount = recorder.count
            var lastChange = Date()
            while Date() < deadline {
                Thread.sleep(forTimeInterval: 0.02)
                let current = recorder.count
                if current != lastCount {
                    lastCount = current
                    lastChange = Date()
                } else if Date().timeIntervalSince(lastChange) >= quietPeriod {
                    return lastCount
                }
            }
            return recorder.count
        }

        private static func makeTempDirectory() -> URL {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("occtswiftio-watcher-\(UUID().uuidString)")
            try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }

        /// Counts the process's open descriptors that point at `directory` or inside it.
        ///
        /// Resolves each descriptor's path with `F_GETPATH`. Returns `-1` if the descriptor table
        /// or the directory's real path can't be read.
        ///
        /// Deliberately not the process-wide descriptor count: Swift Testing runs tests
        /// concurrently, so any other test opening or closing a file (including the other
        /// `DirectoryWatcherTests`, each of which holds a descriptor while its watcher runs)
        /// shifts a process-wide count by one at random (#80). Each test makes its own
        /// UUID-named directory, so only the descriptors a test's own watchers open can land under
        /// it.
        private static func openDescriptorCount(under directory: URL) -> Int {
            // `F_GETPATH` reports the fully resolved path (`/private/var/...`), whereas the
            // temporary directory is spelled through the `/var` symlink, so resolve it the same
            // way. `URL.resolvingSymlinksInPath` is not used: it strips `/private`.
            var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
            guard realpath(directory.path, &resolved) != nil,
                let names = try? FileManager.default.contentsOfDirectory(atPath: "/dev/fd")
            else { return -1 }
            let root = resolved.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }

            var count = 0
            for name in names {
                guard let fd = Int32(name) else { continue }
                var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
                // Fails for descriptors with no path (kqueues, sockets) and for ones another
                // thread closed since the listing; neither can be ours.
                guard fcntl(fd, F_GETPATH, &buffer) != -1 else { continue }
                let path = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
                if path == root || path.hasPrefix(root + "/") { count += 1 }
            }
            return count
        }

        // MARK: - Fires on create/modify within a bounded interval

        @Test func t_firesWhenWatchedFileIsModified() throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let fileURL = dir.appendingPathComponent("watched.txt")
            try "initial".write(toFile: fileURL.path, atomically: false, encoding: .utf8)

            let recorder = Recorder()
            let watcher = DirectoryWatcher(url: fileURL) { recorder.increment() }
            watcher.start()
            defer { watcher.stop() }

            try "changed".write(toFile: fileURL.path, atomically: false, encoding: .utf8)

            #expect(
                Self.waitUntil { recorder.count >= 1 },
                "expected a notification after modifying the watched file")
        }

        @Test func t_firesWhenFileIsCreatedInsideWatchedDirectory() throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }

            let recorder = Recorder()
            let watcher = DirectoryWatcher(url: dir) { recorder.increment() }
            watcher.start()
            defer { watcher.stop() }

            let newFile = dir.appendingPathComponent("created.txt")
            try "hello".write(toFile: newFile.path, atomically: false, encoding: .utf8)

            #expect(
                Self.waitUntil { recorder.count >= 1 },
                "expected a notification after creating a file in the watched directory")
        }

        // MARK: - Ignores dotfile writes; rename-into-place fires exactly once, for the final name

        @Test func t_ignoresDotfileWriteAndFiresOnceForRenameIntoPlace() throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }

            let recorder = Recorder()
            let watcher = DirectoryWatcher(url: dir) { recorder.increment() }
            watcher.start()
            defer { watcher.stop() }

            let id = UUID().uuidString
            let tempURL = dir.appendingPathComponent(".incoming-\(id).json")
            let finalURL = dir.appendingPathComponent("\(id).json")

            try "{}".write(toFile: tempURL.path, atomically: false, encoding: .utf8)

            // Give the dotfile write a real chance to be observed and (correctly) ignored before
            // renaming into place, rather than relying on both operations landing inside a single
            // coalesced kqueue delivery.
            Thread.sleep(forTimeInterval: 0.3)
            #expect(recorder.count == 0, "a dotfile write must not fire a notification")

            try FileManager.default.moveItem(at: tempURL, to: finalURL)

            #expect(
                Self.waitUntil { recorder.count >= 1 },
                "expected a notification after the rename to the final name")
            // Give a further stray duplicate notification a chance to show up before asserting
            // there wasn't one.
            Thread.sleep(forTimeInterval: 0.3)
            #expect(
                recorder.count == 1, "expected exactly one notification, for the final name only")
        }

        // MARK: - Starting on a not-yet-existing path

        @Test func t_startsCleanlyOnNotYetExistingDirectoryAndPicksUpCreation() throws {
            let root = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let notYetExisting = root.appendingPathComponent("later")
            #expect(!FileManager.default.fileExists(atPath: notYetExisting.path))

            let recorder = Recorder()
            let watcher = DirectoryWatcher(url: notYetExisting) { recorder.increment() }
            watcher.start()  // must not throw or crash
            defer { watcher.stop() }

            try FileManager.default.createDirectory(
                at: notYetExisting, withIntermediateDirectories: false)
            let newFile = notYetExisting.appendingPathComponent("payload.json")
            try "{}".write(toFile: newFile.path, atomically: false, encoding: .utf8)

            #expect(
                Self.waitUntil { recorder.count >= 1 },
                "expected a notification once the watched directory is created and written into")
        }

        @Test func t_startsCleanlyWhenMultipleAncestorLevelsAreMissing() throws {
            let root = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            // Two missing levels: neither `root/a` nor `root/a/b` exists yet.
            let level1 = root.appendingPathComponent("a")
            let level2 = level1.appendingPathComponent("b")
            #expect(!FileManager.default.fileExists(atPath: level1.path))
            #expect(!FileManager.default.fileExists(atPath: level2.path))

            let recorder = Recorder()
            let watcher = DirectoryWatcher(url: level2) { recorder.increment() }
            watcher.start()  // must not throw or crash
            defer { watcher.stop() }

            // Create the missing levels one at a time, as a real caller would (e.g. mkdir -p),
            // giving the watcher a chance to cascade its fallback down one level at a time
            // rather than jumping straight to the final target.
            try FileManager.default.createDirectory(at: level1, withIntermediateDirectories: false)
            Thread.sleep(forTimeInterval: 0.3)
            try FileManager.default.createDirectory(at: level2, withIntermediateDirectories: false)
            let newFile = level2.appendingPathComponent("payload.json")
            try "{}".write(toFile: newFile.path, atomically: false, encoding: .utf8)

            #expect(
                Self.waitUntil { recorder.count >= 1 },
                "expected a notification once every missing ancestor level was created and the target written into, not a watcher stuck on the original distant ancestor"
            )
        }

        @Test func t_recoversWhenAFallbackAncestorIsDeletedAndRecreated() throws {
            let root = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let level1 = root.appendingPathComponent("a")
            let level2 = level1.appendingPathComponent("b")

            let recorder = Recorder()
            let watcher = DirectoryWatcher(url: level2) { recorder.increment() }
            watcher.start()

            // Cascade the fallback down onto `root/a`.
            try FileManager.default.createDirectory(at: level1, withIntermediateDirectories: false)
            #expect(
                Self.waitUntil(timeout: 1.0) { FileManager.default.fileExists(atPath: level1.path) }
            )
            Thread.sleep(forTimeInterval: 1.0)

            // Delete the ancestor the fallback is currently watching entirely, then recreate
            // both missing levels at once, as `mkdir -p` would.
            try FileManager.default.removeItem(at: level1)
            Thread.sleep(forTimeInterval: 1.0)
            try FileManager.default.createDirectory(
                at: level2, withIntermediateDirectories: true)
            let newFile = level2.appendingPathComponent("payload.json")
            try "{}".write(toFile: newFile.path, atomically: false, encoding: .utf8)

            #expect(
                Self.waitUntil { recorder.count >= 1 },
                "expected a notification after the watched fallback ancestor was deleted and both missing levels recreated, not a watcher stuck on a stale, unlinked ancestor fd"
            )
            watcher.stop()
        }

        // MARK: - Recovers when the watched directory itself is deleted and recreated

        @Test func t_recoversAfterWatchedDirectoryIsDeletedAndRecreated() throws {
            let root = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let watchedDir = root.appendingPathComponent("output")
            try FileManager.default.createDirectory(
                at: watchedDir, withIntermediateDirectories: false)

            let recorder = Recorder()
            let watcher = DirectoryWatcher(url: watchedDir) { recorder.increment() }
            watcher.start()
            defer { watcher.stop() }

            // Establish that the watcher works before the delete/recreate.
            try "one".write(
                toFile: watchedDir.appendingPathComponent("first.txt").path, atomically: false,
                encoding: .utf8)
            #expect(Self.waitUntil { recorder.count >= 1 }, "expected the baseline write to fire")

            // Simulate a "clear scene" / regenerate step: the directory is removed entirely and
            // recreated at the same path, so the fd the watcher opened now points at an unlinked
            // inode.
            try FileManager.default.removeItem(at: watchedDir)
            try FileManager.default.createDirectory(
                at: watchedDir, withIntermediateDirectories: false)

            // Let any notification triggered by the delete settle before writing again. Without
            // this, `snapshotNonDotfileEntries` re-reads by PATH (not via the stale fd), so a
            // delayed callback from the delete alone can accidentally observe the write below
            // too and mask a watcher that never actually re-attached to the new directory. A
            // fixed sleep here was flaky under load (observed failing about 1 in 8 runs when
            // several other tests in this suite ran back to back): waiting for the count to
            // actually go quiet, rather than guessing a duration, is what makes this reliable.
            let afterRecreate = Self.waitForStableCount(recorder)
            try "two".write(
                toFile: watchedDir.appendingPathComponent("second.txt").path, atomically: false,
                encoding: .utf8)

            #expect(
                Self.waitUntil { recorder.count > afterRecreate },
                "expected a notification for a write into the recreated directory, not a stale fd pointing at the unlinked original"
            )
        }

        // MARK: - No file descriptor leak across repeated start/stop cycles

        @Test func t_repeatedStartStopDoesNotLeakFileDescriptors() throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }

            // Nothing of this test's has opened `dir` yet.
            #expect(Self.openDescriptorCount(under: dir) == 0)

            // Prove the counter can see a watcher's descriptor at all. Without this, a counter
            // that quietly saw nothing (a path mismatch, say) would pass the leak check below
            // vacuously. `start()` opens the descriptor synchronously, so no wait is needed.
            let probe = DirectoryWatcher(url: dir) {}
            probe.start()
            #expect(
                Self.openDescriptorCount(under: dir) == 1,
                "expected a running watcher to hold exactly one descriptor on its directory")
            probe.stop()

            for _ in 0..<50 {
                let watcher = DirectoryWatcher(url: dir) {}
                watcher.start()
                watcher.stop()
            }

            // Cancellation runs asynchronously on each watcher's queue (matching upstream
            // DispatchSourceFileSystemObject / ScriptWatcher semantics), so give it a bounded
            // window to finish closing every descriptor before asserting none is left. A leak
            // would leave one per cycle, so this cannot pass by waiting.
            let settled = Self.waitUntil(timeout: 10.0) {
                Self.openDescriptorCount(under: dir) == 0
            }
            #expect(
                settled,
                "descriptors on the watched directory were not all closed after repeated start/stop cycles"
            )
            #expect(Self.openDescriptorCount(under: dir) == 0)
        }
    }
#endif
