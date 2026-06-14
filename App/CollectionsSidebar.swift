import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// One collection: a custom collapsible header (collection icon · name · trailing
/// chevron) followed by its pinned rows. Collapse state is persisted in the model.
/// The header is a per-collection drop target for pinning files and folders.
struct CollectionDisclosure: View {
    let pinboard: PinboardStore
    let collection: PinnedCollection
    @Binding var openedFile: URL?
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            header
            if !collection.isCollapsed {
                if collection.items.isEmpty {
                    Text("Drag Markdown files or folders here")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 18)
                        .padding(.vertical, 2)
                } else {
                    ForEach(collection.items) { item in
                        rowView(for: item)
                            .padding(.leading, 18)
                    }
                }
            }
        }
    }

    private var header: some View {
        Button {
            pinboard.setCollapsed(collection.id, !collection.isCollapsed)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(collection.name)
                    .font(.system(.subheadline, design: .rounded))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(collection.isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.15), value: collection.isCollapsed)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            let cols = pinboard.pinboard.collections
            if let idx = cols.firstIndex(where: { $0.id == collection.id }) {
                Button("Move Up") {
                    pinboard.moveCollections(fromOffsets: IndexSet(integer: idx), toOffset: idx - 1)
                }
                .disabled(idx == 0)
                Button("Move Down") {
                    pinboard.moveCollections(fromOffsets: IndexSet(integer: idx), toOffset: idx + 2)
                }
                .disabled(idx >= cols.count - 1)
                Divider()
            }
            Button("Rename…", action: onRename)
            Button("Delete Collection", role: .destructive, action: onDelete)
        }
        // Reuse the proven NSItemProvider drop path (security-scope safe).
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            Task { await pinDroppedFiles(providers) }
            return true
        }
    }

    @ViewBuilder
    private func rowView(for item: PinnedItem) -> some View {
        switch item.kind {
        case .file:
            PinnedFileRow(pinboard: pinboard, item: item, collectionID: collection.id, openedFile: $openedFile)
        case .folder:
            FolderPinRow(pinboard: pinboard, item: item, collectionID: collection.id, openedFile: $openedFile)
        }
    }

    @MainActor
    private func pinDroppedFiles(_ providers: [NSItemProvider]) async {
        let urls = await FileDropSupport.loadFileURLs(from: providers)
        for url in urls {
            let std = url.standardizedFileURL
            let isDirectory = (try? std.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                // Folder source: the pinboard stores its own security-scoped
                // folder bookmark (used later to enumerate + open children).
                try? pinboard.pin(std, kind: .folder, to: collection.id)
            } else {
                let ext = std.pathExtension.lowercased()
                guard ext == "md" || ext == "markdown" else { continue }
                // File: register with BookmarkManager so the existing open flow resolves it.
                BookmarkManager.saveBookmark(for: std)
                try? pinboard.pin(std, kind: .file, to: collection.id)
            }
        }
    }
}

/// A single pinned Markdown file. Tagged with its URL so selecting it drives the
/// existing `openedFile` open flow (which resolves the bookmark via BookmarkManager).
struct PinnedFileRow: View {
    let pinboard: PinboardStore
    let item: PinnedItem
    let collectionID: PinnedCollection.ID
    @Binding var openedFile: URL?

    @State private var isStale = false

    var body: some View {
        // Open via an explicit Button action — List(selection:) does not fire
        // reliably for rows nested inside a DisclosureGroup. Setting `openedFile`
        // drives the existing open flow (resolves the bookmark via BookmarkManager).
        Button {
            openedFile = URL(fileURLWithPath: item.path)
        } label: {
            HStack {
                Label(displayName, systemImage: isStale ? "exclamationmark.triangle" : "doc.text")
                    .font(.system(.subheadline, design: .rounded))
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isStale)
        .help(isStale ? "\(item.path) — unavailable (moved or deleted)" : item.path)
        .task(id: item.bookmark) { await checkStale() }
        .contextMenu {
            pinnedItemMenu(pinboard: pinboard, item: item, collectionID: collectionID)
        }
    }

    private var displayName: String {
        (item.displayName as NSString).deletingPathExtension
    }

    /// Resolve the bookmark off the main thread to detect a moved/deleted file.
    /// A bookmark follows a moved file (not stale); only a deleted/unresolvable
    /// one is treated as stale.
    private func checkStale() async {
        let bookmark = item.bookmark
        let resolvable = await Task.detached { () -> Bool in
            var isStaleFlag = false
            let url = try? URL(resolvingBookmarkData: bookmark,
                               options: .withSecurityScope,
                               relativeTo: nil,
                               bookmarkDataIsStale: &isStaleFlag)
            return url != nil
        }.value
        isStale = !resolvable
    }
}

/// A pinned folder source: expands to a live list of the top-level `.md` files
/// inside it. Enumeration runs off the main thread; children are (re)loaded on
/// each expand so the list stays current.
struct FolderPinRow: View {
    let pinboard: PinboardStore
    let item: PinnedItem
    let collectionID: PinnedCollection.ID
    @Binding var openedFile: URL?

    @State private var isExpanded = false
    @State private var children: [URL] = []
    @State private var didLoad = false
    @State private var failed = false

    var body: some View {
        Group {
            header
            if isExpanded {
                if failed {
                    hint("Folder unavailable")
                } else if didLoad && children.isEmpty {
                    hint("No Markdown files")
                } else {
                    // Identify children by path (String), NOT by URL — a URL id
                    // would collide with the List's URL-typed `selection` binding
                    // and auto-highlight every row matching the open file (in every
                    // collection + recents). Opening is driven by the Button, not
                    // selection, so a non-matching id is exactly what we want.
                    ForEach(children, id: \.path) { url in
                        childRow(url)
                    }
                }
            }
        }
    }

    private var header: some View {
        Button {
            isExpanded.toggle()
            if isExpanded { Task { await load() } }
        } label: {
            HStack(spacing: 6) {
                Label(item.displayName, systemImage: "folder")
                    .font(.system(.subheadline, design: .rounded))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.15), value: isExpanded)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.path)
        .contextMenu {
            Button("Refresh") { Task { await load() } }
            pinnedItemMenu(pinboard: pinboard, item: item, collectionID: collectionID)
        }
    }

    private func childRow(_ url: URL) -> some View {
        Button {
            open(url)
        } label: {
            HStack {
                Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.text")
                    .font(.system(.subheadline, design: .rounded))
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(url.path)
        .padding(.leading, 16)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.leading, 16)
            .padding(.vertical, 2)
    }

    /// Resolves the folder bookmark (main actor), then enumerates `.md` files off
    /// the main thread inside the folder's security scope.
    @MainActor
    private func load() async {
        guard let dir = pinboard.resolveURL(for: item) else {
            failed = true
            didLoad = true
            return
        }
        let files = await Task.detached {
            let accessed = dir.startAccessingSecurityScopedResource()
            defer { if accessed { dir.stopAccessingSecurityScopedResource() } }
            return PinboardStore.markdownFiles(in: dir)
        }.value
        children = files
        failed = false
        didLoad = true
    }

    /// Opens a child file. The child is reachable only through the parent folder's
    /// security scope, so we briefly activate it, mint a security-scoped bookmark
    /// for the child (registered with BookmarkManager), then open via the normal flow.
    private func open(_ childURL: URL) {
        if let dir = pinboard.resolveURL(for: item) {
            let accessed = dir.startAccessingSecurityScopedResource()
            defer { if accessed { dir.stopAccessingSecurityScopedResource() } }
            BookmarkManager.saveBookmark(for: childURL)
        }
        openedFile = childURL
    }
}

/// Shared context-menu items for a pinned file or folder: reorder within the
/// collection, move to another collection, reveal, and remove. Uses the store's
/// (unit-tested) mutation methods — reliable, no SwiftUI drag fragility.
@MainActor
@ViewBuilder
func pinnedItemMenu(pinboard: PinboardStore, item: PinnedItem, collectionID: PinnedCollection.ID) -> some View {
    let collections = pinboard.pinboard.collections
    if let collection = collections.first(where: { $0.id == collectionID }),
       let index = collection.items.firstIndex(where: { $0.id == item.id }) {
        Button("Move Up") {
            pinboard.moveItems(in: collectionID, fromOffsets: IndexSet(integer: index), toOffset: index - 1)
        }
        .disabled(index == 0)
        Button("Move Down") {
            pinboard.moveItems(in: collectionID, fromOffsets: IndexSet(integer: index), toOffset: index + 2)
        }
        .disabled(index >= collection.items.count - 1)
    }

    let others = collections.filter { $0.id != collectionID }
    if !others.isEmpty {
        Menu("Move to Collection") {
            ForEach(others) { destination in
                Button(destination.name) {
                    pinboard.moveItem(item.id, to: destination.id)
                }
            }
        }
    }

    Button("Reveal in Finder") {
        let url = pinboard.resolveURL(for: item) ?? URL(fileURLWithPath: item.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    Divider()

    Button("Remove from Collection", role: .destructive) {
        pinboard.removeItem(item.id, from: collectionID)
    }
}
