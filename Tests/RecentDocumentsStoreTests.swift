import XCTest

@MainActor
final class RecentDocumentsStoreTests: XCTestCase {
    /// A store backed by an isolated `UserDefaults` suite and a fake bookmark maker
    /// (so tests need no real security-scoped bookmarks).
    private func makeStore(maxCount: Int = 5, suite: String = UUID().uuidString) -> (RecentDocumentsStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = RecentDocumentsStore(
            defaults: defaults,
            storageKey: "test",
            maxCount: maxCount,
            makeBookmark: { url in Data("bm:\(url.path)".utf8) }
        )
        return (store, defaults)
    }

    private func fileURL(_ path: String) -> URL { URL(fileURLWithPath: path) }

    func testAddInsertsNewestAtTop() {
        let (store, _) = makeStore()
        store.add(url: fileURL("/docs/a.md"))
        store.add(url: fileURL("/docs/b.md"))
        XCTAssertEqual(store.documents.map(\.path), ["/docs/b.md", "/docs/a.md"])
        XCTAssertEqual(store.documents.first?.displayName, "b.md")
    }

    func testAddCapsAtMaxCount() {
        let (store, _) = makeStore(maxCount: 2)
        store.add(url: fileURL("/docs/a.md"))
        store.add(url: fileURL("/docs/b.md"))
        store.add(url: fileURL("/docs/c.md"))
        XCTAssertEqual(store.documents.map(\.path), ["/docs/c.md", "/docs/b.md"], "oldest is evicted")
    }

    func testReopeningKeepsPositionWithoutDuplicating() {
        let (store, _) = makeStore()
        store.add(url: fileURL("/docs/a.md"))
        store.add(url: fileURL("/docs/b.md"))
        store.add(url: fileURL("/docs/a.md")) // re-open the older one
        XCTAssertEqual(store.documents.map(\.path), ["/docs/b.md", "/docs/a.md"], "no reshuffle under the cursor")
        XCTAssertEqual(store.documents.count, 2, "no duplicate entry")
    }

    func testClearEmpties() {
        let (store, _) = makeStore()
        store.add(url: fileURL("/docs/a.md"))
        store.clear()
        XCTAssertTrue(store.documents.isEmpty)
    }

    func testPersistsAcrossReload() {
        let suite = UUID().uuidString
        let (store, defaults) = makeStore(suite: suite)
        store.add(url: fileURL("/docs/a.md"))
        let reloaded = RecentDocumentsStore(defaults: defaults, storageKey: "test", makeBookmark: { _ in Data() })
        XCTAssertEqual(reloaded.documents.map(\.path), ["/docs/a.md"], "recents (with their own bookmark) survive relaunch")
    }

    func testResolveURLRefreshesAndPersistsStaleBookmark() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = RecentDocumentsStore(
            defaults: defaults,
            storageKey: "test",
            makeBookmark: { url in Data("fresh:\(url.path)".utf8) },
            resolveBookmarkData: { _ in (URL(fileURLWithPath: "/docs/moved.md"), true) }
        )
        store.add(url: fileURL("/docs/a.md"))

        let url = store.resolveURL(for: store.documents[0])

        XCTAssertEqual(url?.path, "/docs/moved.md")
        XCTAssertEqual(store.documents.first?.bookmark, Data("fresh:/docs/moved.md".utf8), "stale bookmark is re-minted")
        XCTAssertEqual(store.documents.first?.path, "/docs/moved.md", "path hint follows the move")
    }

    func testResolveURLReturnsNilWhenUnresolvable() {
        let store = RecentDocumentsStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            storageKey: "test",
            makeBookmark: { url in Data("bm:\(url.path)".utf8) },
            resolveBookmarkData: { _ in nil }
        )
        store.add(url: fileURL("/docs/a.md"))
        XCTAssertNil(store.resolveURL(for: store.documents[0]))
    }
}
