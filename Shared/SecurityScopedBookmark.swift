import Foundation

/// One place that mints and resolves app-scoped security-scoped bookmarks, so every
/// store (pins, recents) uses the same options and stale handling instead of each
/// re-implementing `bookmarkData` / `URL(resolvingBookmarkData:)`.
enum SecurityScopedBookmark {
    /// The outcome of resolving a bookmark: the URL plus whether the stored data
    /// went stale and should be re-minted (inside an active security scope).
    typealias Resolution = (url: URL, isStale: Bool)

    static func make(_ url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(_ data: Data) -> Resolution? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: .withSecurityScope,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &isStale) else {
            return nil
        }
        return (url, isStale)
    }
}
