import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private enum SidebarItem: Hashable {
        case preview
    }

    @Binding var openedFile: URL?
    let openMarkdownFile: () -> Void

    @State private var state = MarkdownPreviewState()
    @State private var selection: SidebarItem? = .preview
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 620, idealWidth: 860, minHeight: 480, idealHeight: 720)
            .searchable(text: $searchText, prompt: "Search in document...")
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: openMarkdownFile) {
                        Label("Open", systemImage: "doc.badge.plus")
                    }
                    .help("Open Markdown File")
                }
            }
            .onAppear(perform: loadOpenedFile)
            .onChange(of: openedFile) {
                loadOpenedFile()
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                Task {
                    _ = await loadDroppedFile(from: providers)
                }
                return true
            }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                Label(sidebarTitle, systemImage: "doc.text.magnifyingglass")
                    .tag(SidebarItem.preview)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PeekMark")
    }

    @ViewBuilder
    private var detailContent: some View {
        if state.renderedDocument.isEmpty {
            EmptyStateView()
                .navigationTitle("PeekMark")
        } else {
            MarkdownPreviewView(html: state.renderedDocument.html, searchText: searchText)
                .navigationTitle(state.renderedDocument.title)
        }
    }

    private var sidebarTitle: String {
        if state.renderedDocument.isEmpty {
            return "Preview"
        }

        return state.renderedDocument.title
    }

    private func loadOpenedFile() {
        guard let openedFile else {
            state.clear()
            return
        }
        state.load(url: openedFile)
    }

    private func loadDroppedFile(from providers: [NSItemProvider]) async -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        guard let url = await loadFileURL(from: provider) else {
            return false
        }

        openedFile = url
        return true
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: url)
            }
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Open a Markdown File", systemImage: "doc.richtext")
        } description: {
            Text("Use File > Open, drop a .md file here, or preview from Finder with Space.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView(openedFile: .constant(nil), openMarkdownFile: {})
}
