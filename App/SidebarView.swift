import SwiftUI

struct SidebarView: View {
    @Binding var openedFile: URL?
    @Binding var sessionRecentFiles: [URL]
    @Binding var recentFilesRaw: String
    let pinboard: PinboardStore

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
            recentDocumentsSection
            collectionsSection
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
                    recentFilesRaw = ""
                    sessionRecentFiles = []
                    openedFile = nil
                }) {
                    Text("Clear")
                }
                .buttonStyle(ClearButtonStyle())
                .disabled(sessionRecentFiles.isEmpty)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 6)
            .padding(.top, 4)
        ) {
            if sessionRecentFiles.isEmpty {
                Text("No recent documents")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
            } else {
                ForEach(sessionRecentFiles, id: \.self) { url in
                    HStack {
                        Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.text")
                            .font(.system(.body, design: .rounded))
                            .lineLimit(1)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .tag(url as URL?)
                }
            }
        }
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
