import XCTest

@MainActor
final class PinboardStoreTests: XCTestCase {
    /// A store backed by an isolated `UserDefaults` suite and a fake bookmark
    /// maker (so tests need no real security-scoped bookmarks).
    private func makeStore(suite: String = UUID().uuidString) -> (PinboardStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = PinboardStore(defaults: defaults, storageKey: "test") { url in
            Data("bookmark:\(url.path)".utf8)
        }
        return (store, defaults)
    }

    private func fileURL(_ path: String) -> URL { URL(fileURLWithPath: path) }

    // MARK: Collections

    func testCreateCollection() {
        let (store, _) = makeStore()
        let id = store.createCollection(name: "Agents")
        XCTAssertEqual(store.pinboard.collections.count, 1)
        XCTAssertEqual(store.pinboard.collections.first?.id, id)
        XCTAssertEqual(store.pinboard.collections.first?.name, "Agents")
        XCTAssertFalse(store.pinboard.collections.first!.isCollapsed)
        XCTAssertTrue(store.pinboard.collections.first!.items.isEmpty)
    }

    func testRenameCollectionTrimsAndRejectsEmpty() {
        let (store, _) = makeStore()
        let id = store.createCollection(name: "Old")
        store.renameCollection(id, to: "  New  ")
        XCTAssertEqual(store.pinboard.collections.first?.name, "New")
        store.renameCollection(id, to: "   ")
        XCTAssertEqual(store.pinboard.collections.first?.name, "New", "empty rename is ignored")
    }

    func testDeleteCollection() {
        let (store, _) = makeStore()
        let a = store.createCollection(name: "A")
        _ = store.createCollection(name: "B")
        store.deleteCollection(a)
        XCTAssertEqual(store.pinboard.collections.map(\.name), ["B"])
    }

    func testSetCollapsedPersists() {
        let suite = UUID().uuidString
        let (store, defaults) = makeStore(suite: suite)
        let id = store.createCollection(name: "A")
        store.setCollapsed(id, true)
        let reloaded = PinboardStore(defaults: defaults, storageKey: "test") { _ in Data() }
        XCTAssertEqual(reloaded.pinboard.collections.first?.isCollapsed, true)
    }

    // MARK: Items

    func testPinAddsItem() throws {
        let (store, _) = makeStore()
        let id = store.createCollection(name: "A")
        try store.pin(fileURL("/tmp/notes.md"), kind: .file, to: id)
        let item = try XCTUnwrap(store.pinboard.collections.first?.items.first)
        XCTAssertEqual(item.kind, .file)
        XCTAssertEqual(item.displayName, "notes.md")
        XCTAssertEqual(item.path, "/tmp/notes.md")
        XCTAssertFalse(item.bookmark.isEmpty)
    }

    func testPinDedupesWithinCollection() throws {
        let (store, _) = makeStore()
        let id = store.createCollection(name: "A")
        try store.pin(fileURL("/tmp/notes.md"), kind: .file, to: id)
        try store.pin(fileURL("/tmp/notes.md"), kind: .file, to: id)
        XCTAssertEqual(store.pinboard.collections.first?.items.count, 1, "re-pinning the same path is a no-op")
    }

    func testSamePathAllowedAcrossCollections() throws {
        let (store, _) = makeStore()
        let a = store.createCollection(name: "A")
        let b = store.createCollection(name: "B")
        try store.pin(fileURL("/tmp/notes.md"), kind: .file, to: a)
        try store.pin(fileURL("/tmp/notes.md"), kind: .file, to: b)
        XCTAssertEqual(store.pinboard.collections[0].items.count, 1)
        XCTAssertEqual(store.pinboard.collections[1].items.count, 1)
    }

    func testPinSameNameDifferentPathsBothPinned() throws {
        // Dedupe is by absolute path, not filename: two different files that
        // happen to share a name must both pin.
        let (store, _) = makeStore()
        let id = store.createCollection(name: "A")
        try store.pin(fileURL("/foo/notes.md"), kind: .file, to: id)
        try store.pin(fileURL("/bar/notes.md"), kind: .file, to: id)
        XCTAssertEqual(store.pinboard.collections.first?.items.count, 2)
        XCTAssertEqual(
            Set(store.pinboard.collections.first!.items.map(\.path)),
            ["/foo/notes.md", "/bar/notes.md"]
        )
    }

    func testRemoveItem() throws {
        let (store, _) = makeStore()
        let id = store.createCollection(name: "A")
        try store.pin(fileURL("/tmp/a.md"), kind: .file, to: id)
        let itemID = try XCTUnwrap(store.pinboard.collections.first?.items.first?.id)
        store.removeItem(itemID, from: id)
        XCTAssertTrue(store.pinboard.collections.first!.items.isEmpty)
    }

    func testMoveItemBetweenCollections() throws {
        let (store, _) = makeStore()
        let a = store.createCollection(name: "A")
        let b = store.createCollection(name: "B")
        try store.pin(fileURL("/tmp/a.md"), kind: .file, to: a)
        let itemID = try XCTUnwrap(store.pinboard.collections[0].items.first?.id)
        store.moveItem(itemID, to: b)
        XCTAssertTrue(store.pinboard.collections[0].items.isEmpty)
        XCTAssertEqual(store.pinboard.collections[1].items.first?.path, "/tmp/a.md")
    }

    func testMoveItemsWithinCollectionReorders() throws {
        let (store, _) = makeStore()
        let id = store.createCollection(name: "A")
        try store.pin(fileURL("/tmp/1.md"), kind: .file, to: id)
        try store.pin(fileURL("/tmp/2.md"), kind: .file, to: id)
        try store.pin(fileURL("/tmp/3.md"), kind: .file, to: id)
        store.moveItems(in: id, fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(store.pinboard.collections.first?.items.map(\.displayName), ["2.md", "3.md", "1.md"])
    }

    // MARK: Persistence + enumeration

    func testPersistenceRoundTrip() throws {
        let suite = UUID().uuidString
        let (store, defaults) = makeStore(suite: suite)
        let id = store.createCollection(name: "Agents")
        try store.pin(fileURL("/tmp/x.md"), kind: .file, to: id)
        let reloaded = PinboardStore(defaults: defaults, storageKey: "test") { _ in Data() }
        XCTAssertEqual(reloaded.pinboard, store.pinboard)
    }

    func testLoadsEmptyWhenNoStoredData() {
        let (store, _) = makeStore()
        XCTAssertEqual(store.pinboard, .empty)
    }

    func testMarkdownFilesFiltersAndSorts() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        for name in ["Beta.md", "alpha.markdown", "ignore.txt", "Gamma.MD"] {
            try Data().write(to: dir.appendingPathComponent(name))
        }
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)

        let names = PinboardStore.markdownFiles(in: dir).map { $0.lastPathComponent }
        XCTAssertEqual(
            names, ["alpha.markdown", "Beta.md", "Gamma.MD"],
            "only top-level .md/.markdown (case-insensitive), sorted, excluding .txt and subdirectories"
        )
    }

    // MARK: Stale-bookmark refresh

    func testResolveURLRefreshesAndPersistsStaleBookmark() throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        // Resolver reports the bookmark as stale and points at a new location, so
        // resolveURL must re-mint and write the fresh bookmark back into the item.
        let store = PinboardStore(
            defaults: defaults,
            storageKey: "test",
            makeBookmark: { url in Data("fresh:\(url.path)".utf8) },
            resolveBookmarkData: { _ in (URL(fileURLWithPath: "/docs/moved.md"), true) }
        )
        let cid = store.createCollection(name: "A")
        try store.pin(fileURL("/docs/notes.md"), kind: .file, to: cid)
        let original = try XCTUnwrap(store.pinboard.collections.first?.items.first)

        _ = store.resolveURL(for: original)

        let refreshed = try XCTUnwrap(store.pinboard.collections.first?.items.first)
        XCTAssertEqual(refreshed.id, original.id, "item identity is preserved")
        XCTAssertEqual(refreshed.bookmark, Data("fresh:/docs/moved.md".utf8), "stale bookmark is re-minted")
        XCTAssertEqual(refreshed.path, "/docs/moved.md", "path hint follows the re-minted location")

        let reloaded = PinboardStore(defaults: defaults, storageKey: "test") { _ in Data() }
        XCTAssertEqual(
            reloaded.pinboard.collections.first?.items.first?.bookmark,
            Data("fresh:/docs/moved.md".utf8),
            "the refreshed bookmark is persisted"
        )
    }

    func testResolveURLLeavesFreshBookmarkUntouched() throws {
        let store = PinboardStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            storageKey: "test",
            makeBookmark: { url in Data("bm:\(url.path)".utf8) },
            resolveBookmarkData: { _ in (URL(fileURLWithPath: "/docs/notes.md"), false) }
        )
        let cid = store.createCollection(name: "A")
        try store.pin(fileURL("/docs/notes.md"), kind: .file, to: cid)
        let before = try XCTUnwrap(store.pinboard.collections.first?.items.first?.bookmark)

        _ = store.resolveURL(for: try XCTUnwrap(store.pinboard.collections.first?.items.first))

        let after = try XCTUnwrap(store.pinboard.collections.first?.items.first?.bookmark)
        XCTAssertEqual(before, after, "a non-stale bookmark is left untouched")
    }
}
