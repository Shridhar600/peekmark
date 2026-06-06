import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// One collection rendered as a collapsible disclosure of pinned file rows, with
/// a per-collection drop target for pinning Markdown files. Collapse state is
/// bound to the model so it persists.
struct CollectionDisclosure: View {
    let pinboard: PinboardStore
    let collection: PinnedCollection
    @Binding var openedFile: URL?
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: expandedBinding) {
            if collection.items.isEmpty {
                Text("Drag Markdown files here")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                ForEach(collection.items) { item in
                    PinnedFileRow(pinboard: pinboard, item: item, collectionID: collection.id)
                }
            }
        } label: {
            Text(collection.name)
                .font(.system(.body, design: .rounded))
                .lineLimit(1)
                .contextMenu {
                    Button("Rename…", action: onRename)
                    Button("Delete Collection", role: .destructive, action: onDelete)
                }
        }
        // Reuse the proven NSItemProvider drop path (security-scope safe).
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            Task { await pinDroppedFiles(providers) }
            return true
        }
    }

    private var expandedBinding: Binding<Bool> {
        Binding(
            get: { !collection.isCollapsed },
            set: { pinboard.setCollapsed(collection.id, !$0) }
        )
    }

    @MainActor
    private func pinDroppedFiles(_ providers: [NSItemProvider]) async {
        let urls = await FileDropSupport.loadFileURLs(from: providers)
        for url in urls {
            let std = url.standardizedFileURL
            let ext = std.pathExtension.lowercased()
            // Stage 2: Markdown files only. Folder sources arrive in Stage 3.
            guard ext == "md" || ext == "markdown" else { continue }
            let isDirectory = (try? std.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard !isDirectory else { continue }
            // Register with BookmarkManager so the existing open flow can resolve it.
            BookmarkManager.saveBookmark(for: std)
            try? pinboard.pin(std, kind: .file, to: collection.id)
        }
    }
}

/// A single pinned Markdown file. Tagged with its URL so selecting it drives the
/// existing `openedFile` open flow (which resolves the bookmark via BookmarkManager).
struct PinnedFileRow: View {
    let pinboard: PinboardStore
    let item: PinnedItem
    let collectionID: PinnedCollection.ID

    var body: some View {
        HStack {
            Label(displayName, systemImage: "doc.text")
                .font(.system(.body, design: .rounded))
                .lineLimit(1)
            Spacer()
        }
        .contentShape(Rectangle())
        .tag(URL(fileURLWithPath: item.path) as URL?)
        .contextMenu {
            Button("Reveal in Finder") { revealInFinder() }
            Button("Remove from Collection", role: .destructive) {
                pinboard.removeItem(item.id, from: collectionID)
            }
        }
    }

    private var displayName: String {
        (item.displayName as NSString).deletingPathExtension
    }

    private func revealInFinder() {
        let url = pinboard.resolveURL(for: item) ?? URL(fileURLWithPath: item.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
