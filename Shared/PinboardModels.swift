import Foundation

/// The whole organizer: an ordered list of user-named collections.
struct Pinboard: Codable, Equatable {
    var collections: [PinnedCollection]

    static let empty = Pinboard(collections: [])
}

/// A user-named section ("Agents", "Projects", …) holding pinned items.
struct PinnedCollection: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var isCollapsed: Bool
    var items: [PinnedItem]

    init(id: UUID = UUID(), name: String, isCollapsed: Bool = false, items: [PinnedItem] = []) {
        self.id = id
        self.name = name
        self.isCollapsed = isCollapsed
        self.items = items
    }
}

/// A pinned reference to a Markdown file or a folder source. The `bookmark` is a
/// security-scoped bookmark and is authoritative for sandbox access; `path` is a
/// hint captured at pin time, used for dedupe / display / reveal-in-Finder.
struct PinnedItem: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case file, folder }

    var id: UUID
    var kind: Kind
    var displayName: String
    var path: String
    var bookmark: Data

    init(id: UUID = UUID(), kind: Kind, displayName: String, path: String, bookmark: Data) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.path = path
        self.bookmark = bookmark
    }
}
