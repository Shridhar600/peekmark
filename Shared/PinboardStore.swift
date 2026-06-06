import Foundation
import Observation

/// Single source of truth for the sidebar organizer: owns the `Pinboard` model,
/// JSON persistence in `UserDefaults`, all mutations, security-scoped bookmark
/// creation/resolution, and folder enumeration.
///
/// Pure Foundation + Observation (no SwiftUI) so it lives in `Shared/` and is
/// unit-testable. `makeBookmark` and `defaults` are injectable seams so tests run
/// without real security-scoped bookmarks or the shared `UserDefaults`.
@MainActor
@Observable
final class PinboardStore {
    private(set) var pinboard: Pinboard

    private let defaults: UserDefaults
    private let storageKey: String
    private let makeBookmark: (URL) throws -> Data

    init(defaults: UserDefaults = .standard,
         storageKey: String = "pinboard.v1",
         makeBookmark: @escaping (URL) throws -> Data = PinboardStore.defaultMakeBookmark) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.makeBookmark = makeBookmark
        self.pinboard = PinboardStore.load(defaults: defaults, key: storageKey)
    }

    // MARK: - Collections

    @discardableResult
    func createCollection(name: String) -> PinnedCollection.ID {
        let collection = PinnedCollection(name: name)
        pinboard.collections.append(collection)
        persist()
        return collection.id
    }

    func renameCollection(_ id: PinnedCollection.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = index(of: id) else { return }
        pinboard.collections[idx].name = trimmed
        persist()
    }

    func deleteCollection(_ id: PinnedCollection.ID) {
        pinboard.collections.removeAll { $0.id == id }
        persist()
    }

    func setCollapsed(_ id: PinnedCollection.ID, _ collapsed: Bool) {
        guard let idx = index(of: id) else { return }
        pinboard.collections[idx].isCollapsed = collapsed
        persist()
    }

    func moveCollections(fromOffsets: IndexSet, toOffset: Int) {
        Self.reorder(&pinboard.collections, fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    // MARK: - Items

    /// Pins `url` into the given collection, creating a security-scoped bookmark.
    /// Dedupes within that collection by path (re-pinning the same file is a no-op).
    func pin(_ url: URL, kind: PinnedItem.Kind, to collectionID: PinnedCollection.ID) throws {
        let std = url.standardizedFileURL
        guard let idx = index(of: collectionID) else { return }
        if pinboard.collections[idx].items.contains(where: { $0.path == std.path }) { return }
        let bookmark = try makeBookmark(std)
        let item = PinnedItem(kind: kind, displayName: std.lastPathComponent, path: std.path, bookmark: bookmark)
        pinboard.collections[idx].items.append(item)
        persist()
    }

    func removeItem(_ itemID: PinnedItem.ID, from collectionID: PinnedCollection.ID) {
        guard let idx = index(of: collectionID) else { return }
        pinboard.collections[idx].items.removeAll { $0.id == itemID }
        persist()
    }

    func moveItems(in collectionID: PinnedCollection.ID, fromOffsets: IndexSet, toOffset: Int) {
        guard let idx = index(of: collectionID) else { return }
        Self.reorder(&pinboard.collections[idx].items, fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    /// Moves an item to another collection. No-op (but still removes from source)
    /// if the destination already contains the same path.
    func moveItem(_ itemID: PinnedItem.ID, to destinationID: PinnedCollection.ID, at targetIndex: Int? = nil) {
        guard let srcIdx = pinboard.collections.firstIndex(where: { $0.items.contains { $0.id == itemID } }),
              let itemPos = pinboard.collections[srcIdx].items.firstIndex(where: { $0.id == itemID }),
              let dstIdx = index(of: destinationID) else { return }
        let item = pinboard.collections[srcIdx].items.remove(at: itemPos)
        if pinboard.collections[dstIdx].items.contains(where: { $0.path == item.path }) {
            persist()
            return
        }
        let count = pinboard.collections[dstIdx].items.count
        let insertAt = min(targetIndex ?? count, count)
        pinboard.collections[dstIdx].items.insert(item, at: insertAt)
        persist()
    }

    // MARK: - Resolution / enumeration

    /// Resolves a pinned item's bookmark to a usable URL. The caller is responsible
    /// for `startAccessingSecurityScopedResource()` / `stop…`. Returns nil if the
    /// bookmark is stale or unresolvable (e.g. the file was moved or deleted).
    func resolveURL(for item: PinnedItem) -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: item.bookmark,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
    }

    /// Top-level Markdown files in `directory`, sorted case-insensitively by name.
    /// (No recursion into subfolders — v1.)
    nonisolated static func markdownFiles(in directory: URL) -> [URL] {
        let exts: Set<String> = ["md", "markdown"]
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles])) ?? []
        return contents
            .filter { exts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    // MARK: - Persistence

    private func index(of id: PinnedCollection.ID) -> Int? {
        pinboard.collections.firstIndex { $0.id == id }
    }

    /// Reorders `array` in place with the same semantics as SwiftUI's
    /// `move(fromOffsets:toOffset:)`, but using only the standard library so the
    /// store stays free of a SwiftUI dependency. The UI's `.onMove` can call the
    /// public wrappers with the exact offsets it provides.
    nonisolated private static func reorder<T>(_ array: inout [T], fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { array[$0] }
        for index in source.sorted(by: >) {
            array.remove(at: index)
        }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        array.insert(contentsOf: moving, at: adjustedDestination)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(pinboard) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func load(defaults: UserDefaults, key: String) -> Pinboard {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Pinboard.self, from: data) else {
            return .empty
        }
        return decoded
    }

    nonisolated static func defaultMakeBookmark(_ url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
