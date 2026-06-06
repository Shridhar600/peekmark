import Foundation
import UniformTypeIdentifiers
import os

/// Loads file URLs from dropped `NSItemProvider`s using the same mechanism as the
/// window-level drop (`URL(dataRepresentation:)`), which reliably preserves the
/// sandbox extension needed to create a security-scoped bookmark — unlike
/// `.dropDestination(for: URL.self)` for Finder file drops.
enum FileDropSupport {
    @MainActor
    static func loadFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        return urls
    }

    @MainActor
    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            let flag = OSAllocatedUnfairLock(initialState: false)

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                flag.withLock { hasResumed in
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: nil)
                    }
                }
            }

            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let data = item as? Data
                timeoutTask.cancel()
                flag.withLock { hasResumed in
                    if !hasResumed {
                        hasResumed = true
                        if let data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
        }
    }
}
