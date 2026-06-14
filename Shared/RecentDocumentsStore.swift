import Foundation
import Observation

/// A recently-opened Markdown file that carries its OWN security-scoped bookmark,
/// so it reliably reopens after relaunch under the sandbox — independent of any
/// other bookmark store (the previous design persisted only a raw path string and
/// silently broke whenever the shared bookmark dictionary drifted).
struct RecentDocument: Codable, Identifiable, Hashable {
    var id: UUID
    var displayName: String
    var path: String
    var bookmark: Data

    init(id: UUID = UUID(), displayName: String, path: String, bookmark: Data) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.bookmark = bookmark
    }
}

/// Owns the recent-documents list: JSON persistence in `UserDefaults`, capped size,
/// security-scoped bookmark creation/resolution with stale re-minting. Pure
/// Foundation + Observation so it lives in `Shared/` and is unit-testable via the
/// injectable `makeBookmark` / `resolveBookmarkData` seams.
@MainActor
@Observable
final class RecentDocumentsStore {
    private(set) var documents: [RecentDocument] = []

    private let maxCount: Int
    private let defaults: UserDefaults
    private let storageKey: String
    private let makeBookmark: (URL) throws -> Data
    private let resolveBookmarkData: (Data) -> SecurityScopedBookmark.Resolution?

    init(defaults: UserDefaults = .standard,
         storageKey: String = "recentDocuments.v1",
         maxCount: Int = 10,
         makeBookmark: @escaping (URL) throws -> Data = SecurityScopedBookmark.make,
         resolveBookmarkData: @escaping (Data) -> SecurityScopedBookmark.Resolution? = SecurityScopedBookmark.resolve) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maxCount = maxCount
        self.makeBookmark = makeBookmark
        self.resolveBookmarkData = resolveBookmarkData
        self.documents = Self.load(defaults: defaults, key: storageKey)
    }

    /// Records `url` as recently opened, minting its own security-scoped bookmark.
    /// A doc already in the list keeps its position (no reshuffle under the cursor)
    /// and just refreshes its bookmark; a new doc goes to the top. Capped at `maxCount`.
    ///
    /// Minting happens against `url` as passed (a URL from a resolved bookmark or an
    /// open panel carries the access token); we briefly activate its scope here so
    /// callers don't have to. The path *hint* is standardized for dedupe/display.
    func add(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let bookmark = try? makeBookmark(url) else { return }
        let path = url.standardizedFileURL.path
        let name = url.lastPathComponent

        if let idx = documents.firstIndex(where: { $0.path == path }) {
            documents[idx].bookmark = bookmark
            documents[idx].displayName = name
        } else {
            documents.insert(RecentDocument(displayName: name, path: path, bookmark: bookmark), at: 0)
            if documents.count > maxCount {
                documents = Array(documents.prefix(maxCount))
            }
        }
        persist()
    }

    func clear() {
        documents = []
        persist()
    }

    /// Resolves a recent's bookmark to a usable URL (the caller owns the
    /// `startAccessingSecurityScopedResource()` / `stop…`), re-minting and
    /// persisting if the bookmark went stale. Returns nil if unresolvable.
    func resolveURL(for document: RecentDocument) -> URL? {
        guard let resolution = resolveBookmarkData(document.bookmark) else { return nil }
        if resolution.isStale {
            refreshBookmark(for: document.id, resolvedURL: resolution.url)
        }
        return resolution.url
    }

    private func refreshBookmark(for id: RecentDocument.ID, resolvedURL: URL) {
        let accessed = resolvedURL.startAccessingSecurityScopedResource()
        defer { if accessed { resolvedURL.stopAccessingSecurityScopedResource() } }
        guard let fresh = try? makeBookmark(resolvedURL),
              let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].bookmark = fresh
        documents[idx].path = resolvedURL.standardizedFileURL.path
        documents[idx].displayName = resolvedURL.lastPathComponent
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func load(defaults: UserDefaults, key: String) -> [RecentDocument] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentDocument].self, from: data) else {
            return []
        }
        return decoded
    }
}
