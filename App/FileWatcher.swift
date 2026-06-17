import Foundation

/// Watches a single file for external edits and calls `onChange` (debounced) so the
/// preview can refresh live while the user edits in another app.
///
/// Re-arms across atomic saves — an editor that writes a temp file and renames it
/// over the original invalidates the file descriptor, so a `.delete`/`.rename`
/// event re-opens the same path. Holds the file's security scope for the duration
/// (the descriptor needs it). Main-actor; the dispatch source delivers on the main
/// queue.
@MainActor
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var didStartScope = false
    private var debounceTask: Task<Void, Never>?
    private var onChange: (() -> Void)?

    /// Begins watching `url`, replacing any current watch. `onChange` fires on the
    /// main actor after edits settle (~300 ms debounce).
    func start(watching url: URL, onChange: @escaping () -> Void) {
        stop()
        watchedURL = url
        self.onChange = onChange
        didStartScope = url.startAccessingSecurityScopedResource()
        arm()
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        source?.cancel() // the cancel handler closes the descriptor
        source = nil
        if didStartScope, let watchedURL {
            watchedURL.stopAccessingSecurityScopedResource()
        }
        didStartScope = false
        watchedURL = nil
        onChange = nil
    }

    private func arm() {
        guard let watchedURL else { return }
        let fd = open(watchedURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.handleEvent() }
        }
        src.setCancelHandler { close(fd) }
        source = src
        src.resume()
    }

    private func handleEvent() {
        guard let flags = source?.data else { return }
        if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
            // The file was replaced (atomic save) or removed: drop the dead source,
            // re-open the same path after a short settle, then refresh.
            source?.cancel()
            source = nil
            debounceTask?.cancel()
            debounceTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled, self.watchedURL != nil else { return }
                self.arm()
                self.onChange?()
            }
        } else {
            scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            self.onChange?()
        }
    }
}
