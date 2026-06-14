import SwiftUI

struct SidebarView: View {
    @Binding var openedFile: URL?
    let recents: RecentDocumentsStore
    let pinboard: PinboardStore
    @Environment(ErrorPresenter.self) private var errorPresenter: ErrorPresenter?

    // Collection create/rename/delete are driven by alerts (not inline TextField
    // editing inside a List, which is a classic focus-bug source). State lives
    // here so the `.alert` modifiers attach to the real `List` view.
    @State private var showNewCollectionAlert = false
    @State private var newCollectionName = ""
    @State private var renameTarget: PinnedCollection.ID?
    @State private var renameText = ""
    @State private var deleteTarget: PinnedCollection.ID?

    var body: some View {
        List(selection: $openedFile) {
            // Collections (curated, stable) on top; Recent Documents (dynamic,
            // grows as you open files) below — so opening a doc never shoves the
            // collections around. Mirrors Finder's Favorites-on-top convention.
            collectionsSection
            recentDocumentsSection
        }
        .listStyle(.sidebar)
        .scrollIndicators(.automatic)
        .navigationTitle("PeekMark")
        // Document detail (StatsHUDView) is disabled here — the sidebar is now
        // purely for file management. It will be relocated to an `info.circle`
        // button + popover in the top bar (organizer spec, Stage 5).
        // .safeAreaInset(edge: .bottom) {
        //     StatsHUDView(state: state)
        // }
        .alert("New Collection", isPresented: $showNewCollectionAlert) {
            TextField("Name", text: $newCollectionName)
            Button("Create") {
                let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { pinboard.createCollection(name: name) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Collection", isPresented: renameIsPresented) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let id = renameTarget { pinboard.renameCollection(id, to: renameText) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Collection?", isPresented: deleteIsPresented) {
            Button("Delete", role: .destructive) {
                if let id = deleteTarget { pinboard.deleteCollection(id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the collection and its pins. Your files are not deleted.")
        }
    }

    // MARK: - Recent Documents

    private var recentDocumentsSection: some View {
        Section(header:
            HStack {
                Text("Recent Documents")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    recents.clear()
                    openedFile = nil
                }) {
                    Text("Clear")
                }
                .buttonStyle(ClearButtonStyle())
                .disabled(recents.documents.isEmpty)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 6)
            .padding(.top, 4)
        ) {
            if recents.documents.isEmpty {
                Text("No recent documents")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
            } else {
                ForEach(recents.documents) { document in
                    Button {
                        openRecent(document)
                    } label: {
                        HStack {
                            Label((document.displayName as NSString).deletingPathExtension, systemImage: "doc.text")
                                .font(.system(.subheadline, design: .rounded))
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if !pinboard.pinboard.collections.isEmpty {
                            Menu("Add to Collection") {
                                ForEach(pinboard.pinboard.collections) { collection in
                                    Button(collection.name) {
                                        addRecentToCollection(document, collection.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Resolves a recent's own bookmark (re-minting if stale), hydrates the shared
    /// BookmarkManager so the standard open flow can reach it, then opens it.
    private func openRecent(_ document: RecentDocument) {
        guard let url = recents.resolveURL(for: document) else {
            errorPresenter?.present(
                "Can’t Open Document",
                "“\(displayName(of: document))” may have been moved or deleted."
            )
            return
        }
        BookmarkManager.saveBookmark(for: url)
        openedFile = url
    }

    /// Pins a recent into a collection. The recent's bookmark is resolved and its
    /// security scope held open while `pin` mints its own bookmark — otherwise the
    /// file isn't accessible at mint time and the pin silently fails.
    private func addRecentToCollection(_ document: RecentDocument, _ collectionID: PinnedCollection.ID) {
        guard let url = recents.resolveURL(for: document) else {
            errorPresenter?.present(
                "Can’t Add to Collection",
                "“\(displayName(of: document))” may have been moved or deleted."
            )
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        BookmarkManager.saveBookmark(for: url)
        try? pinboard.pin(url, kind: .file, to: collectionID)
    }

    private func displayName(of document: RecentDocument) -> String {
        (document.displayName as NSString).deletingPathExtension
    }

    // MARK: - Collections

    private var collectionsSection: some View {
        Section(header:
            HStack {
                Text("Collections")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    newCollectionName = ""
                    showNewCollectionAlert = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New Collection")
            }
            .padding(.trailing, 16)
            .padding(.bottom, 6)
            .padding(.top, 4)
        ) {
            if pinboard.pinboard.collections.isEmpty {
                Text("Create a collection to pin files")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
            } else {
                ForEach(pinboard.pinboard.collections) { collection in
                    CollectionDisclosure(
                        pinboard: pinboard,
                        collection: collection,
                        openedFile: $openedFile,
                        onRename: {
                            renameText = collection.name
                            renameTarget = collection.id
                        },
                        onDelete: { deleteTarget = collection.id }
                    )
                }
            }
        }
    }

    private var renameIsPresented: Binding<Bool> {
        Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
    }

    private var deleteIsPresented: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }
}

struct ClearButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(isHovered ? .primary : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background {
                Capsule()
                    .fill(isHovered ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.08))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
