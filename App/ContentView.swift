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
    @State private var scrollToHeaderIndex: Int?
    @State private var selectedAppearance: MarkdownAppearance = .system
    
    @AppStorage("recentFiles") private var recentFilesRaw: String = ""

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, idealWidth: 960, minHeight: 520, idealHeight: 760)
        .searchable(text: $searchText, prompt: "Search in document...")
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            // Left Action - Open File
            ToolbarItemGroup(placement: .navigation) {
                Button(action: openMarkdownFile) {
                    Label("Open", systemImage: "doc.badge.plus")
                }
                .help("Open Markdown File")
            }
            
            // Spacer to separate elements
            ToolbarItem {
                Spacer()
            }
            
            // Right Actions - Theme and Copy Controls
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Theme", selection: $selectedAppearance) {
                    Image(systemName: "circle.righthalf.filled").tag(MarkdownAppearance.system)
                    Image(systemName: "sun.max.fill").tag(MarkdownAppearance.light)
                    Image(systemName: "moon.fill").tag(MarkdownAppearance.dark)
                }
                .pickerStyle(.segmented)
                .help("Appearance Mode")
                
                Menu {
                    Button(action: copyMarkdown) {
                        Label("Copy Markdown Source", systemImage: "doc.on.doc")
                    }
                    Button(action: copyHTML) {
                        Label("Copy Rendered HTML", systemImage: "code")
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.clipboard")
                }
                .help("Copy content options")
            }
        }
        .onAppear(perform: loadOpenedFile)
        .onChange(of: openedFile) {
            loadOpenedFile()
        }
        .onChange(of: selectedAppearance) {
            if let openedFile {
                state.load(url: openedFile, appearance: selectedAppearance)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            Task {
                _ = await loadDroppedFile(from: providers)
            }
            return true
        }
    }

    private var sidebar: some View {
        List {
            // 1. Document Outline / TOC Section
            if !state.renderedDocument.headings.isEmpty {
                Section(header: Text("Document Outline")) {
                    ForEach(Array(state.renderedDocument.headings.enumerated()), id: \.element.id) { index, heading in
                        Button(action: {
                            scrollToHeaderIndex = index
                        }) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: "number")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .frame(width: 12)
                                Text(heading.title)
                                    .font(.system(.body, design: .rounded))
                                    .lineLimit(1)
                            }
                            .padding(.leading, CGFloat((heading.level - 1) * 10))
                        }
                        .buttonStyle(.plain)
                        .help("Scroll to \(heading.title)")
                    }
                }
            }
            
            // 2. Recent Documents Section
            let recents = recentFiles
            if !recents.isEmpty {
                Section(header: Text("Recent Documents")) {
                    ForEach(recents, id: \.self) { url in
                        Button(action: {
                            openedFile = url
                        }) {
                            Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.text")
                                .font(.system(.body, design: .rounded))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .help(url.path)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PeekMark")
        .safeAreaInset(edge: .bottom) {
            statsHUD
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if state.renderedDocument.isEmpty {
            EmptyStateView()
                .navigationTitle("PeekMark")
        } else {
            MarkdownPreviewView(
                html: state.renderedDocument.html,
                searchText: searchText,
                scrollToHeaderIndex: $scrollToHeaderIndex
            )
            .navigationTitle(state.renderedDocument.title)
        }
    }

    @ViewBuilder
    private var statsHUD: some View {
        if !state.renderedDocument.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    Text("Document Stats")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 2)
                
                HStack {
                    Text("Words:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(state.wordCount)")
                        .fontWeight(.medium)
                }
                .font(.system(.footnote, design: .rounded))
                
                HStack {
                    Text("Characters:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(state.characterCount)")
                        .fontWeight(.medium)
                }
                .font(.system(.footnote, design: .rounded))
                
                HStack {
                    Text("Reading Time:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(state.readingTimeMinutes) min")
                        .fontWeight(.medium)
                }
                .font(.system(.footnote, design: .rounded))
            }
            .padding(12)
            .modifier(StatsHUDBackgroundModifier())
            .padding()
        }
    }

    private var recentFiles: [URL] {
        recentFilesRaw.split(separator: "|").compactMap { URL(string: String($0)) }
    }

    private func addToRecentFiles(_ url: URL) {
        var current = recentFiles.filter { $0 != url }
        current.insert(url, at: 0)
        if current.count > 5 {
            current = Array(current.prefix(5))
        }
        recentFilesRaw = current.map { $0.absoluteString }.joined(separator: "|")
    }

    private func copyMarkdown() {
        guard !state.renderedDocument.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(state.renderedDocument.rawMarkdown, forType: .string)
    }

    private func copyHTML() {
        guard !state.renderedDocument.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(state.renderedDocument.html, forType: .string)
    }

    private func loadOpenedFile() {
        guard let openedFile else {
            state.clear()
            return
        }
        state.load(url: openedFile, appearance: selectedAppearance)
        addToRecentFiles(openedFile)
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

private struct StatsHUDBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 16.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
