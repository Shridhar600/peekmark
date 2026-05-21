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
    

    
    // Typography popover toggle
    @State private var showTypographyPopover = false
    
    // Metadata HUD states
    @State private var isMetadataExpanded = false
    @State private var showAllMetadata = false
    
    @State private var sessionRecentFiles: [URL] = []
    @AppStorage("recentFiles") private var recentFilesRaw: String = ""
    @AppStorage("previewFont") private var selectedFont: PreviewFont = .system
    @AppStorage("previewSpacing") private var selectedSpacing: PreviewSpacing = .compact
    @AppStorage("previewFontSize") private var selectedFontSize: Double = 14.5
    @AppStorage("previewAppearance") private var selectedAppearance: MarkdownAppearance = .system

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, idealWidth: 1020, minHeight: 520, idealHeight: 780)
        .searchable(text: $searchText, prompt: "Search in document...")
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        // toolbarBackground(.thinMaterial, for: .windowToolbar)
        .toolbar {
            // Left Action - Native placement for Open
            ToolbarItem(placement: .navigation) {
                Button(action: openMarkdownFile) {
                    Label("Open File...", systemImage: "doc.badge.plus")
                }
                .keyboardShortcut("o", modifiers: .command)
                .help("Open Markdown File")
            }

            // Right Actions for Perfect Spacing and Alignment
            ToolbarItemGroup(placement: .primaryAction) {
                if let url = openedFile {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .help("Share Markdown File")
                    .disabled(state.renderedDocument.isEmpty)
                } else {
                    Button(action: {}) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(true)
                    .help("Share Markdown File")
                }

                Button(action: copyMarkdown) {
                    Label("Copy Source", systemImage: "doc.on.doc")
                }
                .help("Copy Markdown Source")
                .disabled(state.renderedDocument.isEmpty)

                Button(action: { showTypographyPopover.toggle() }) {
                    Label("Text Style", systemImage: "textformat.size")
                }
                .keyboardShortcut("t", modifiers: .command)
                .help("Adjust preview layout and typography")
                .popover(isPresented: $showTypographyPopover, arrowEdge: .bottom) {
                    typographyPopoverContent
                }
            }
        }
        .onAppear {
            selectedAppearance = .system
            sessionRecentFiles = persistentRecentFiles
            loadOpenedFile()
        }
        .onChange(of: openedFile) {
            loadOpenedFile()
        }
        .onChange(of: selectedAppearance) {
            updateStyle()
        }
        .onChange(of: selectedFont) {
            updateStyle()
        }
        .onChange(of: selectedSpacing) {
            updateStyle()
        }
        .onChange(of: selectedFontSize) {
            updateStyle()
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            Task {
                _ = await loadDroppedFile(from: providers)
            }
            return true
        }
    }

    private var sidebar: some View {
        List(selection: $openedFile) {
            // Recent Documents Section
            let recents = sessionRecentFiles
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
                    .disabled(recents.isEmpty)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 6)
                .padding(.top, 4)
            ) {
                if recents.isEmpty {
                    Text("No recent documents")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                } else {
                    ForEach(recents, id: \.self) { url in
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
        .listStyle(.sidebar)
        .navigationTitle("PeekMark")
        .safeAreaInset(edge: .bottom) {
            statsHUD
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if state.renderedDocument.isEmpty {
            EmptyStateView(openMarkdownFile: openMarkdownFile)
                .navigationTitle("PeekMark")
        } else {
            VStack(spacing: 0) {
                MarkdownPreviewView(
                    html: state.renderedDocument.html,
                    searchText: searchText,
                    scrollToHeaderIndex: $scrollToHeaderIndex,
                    documentTitle: state.renderedDocument.title
                )
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                    Task {
                        _ = await loadDroppedFile(from: providers)
                    }
                    return true
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let url = openedFile {
                    bottomFooter(for: url)
                }
            }
            .navigationTitle(state.renderedDocument.title)
        }
    }

    private func breadcrumbView(for url: URL) -> some View {
        let components = url.resolvingSymlinksInPath().pathComponents.filter { $0 != "/" && !$0.isEmpty }
        
        let displayComponents = components.count > 3 ? ["…"] + components.suffix(3) : components
        
        return Group {
            switch displayComponents.count {
            case 0:
                Text("")
            case 1:
                Text(displayComponents[0])
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.primary)
            case 2:
                Text("\(Text(displayComponents[0]).font(.system(.caption, design: .rounded)).foregroundColor(.secondary)) \(Text("›").font(.system(.caption, design: .rounded)).foregroundColor(.secondary.opacity(0.6))) \(Text(displayComponents[1]).font(.system(.caption, design: .rounded)).foregroundColor(.primary))")
            case 3:
                Text("\(Text(displayComponents[0]).font(.system(.caption, design: .rounded)).foregroundColor(.secondary)) \(Text("›").font(.system(.caption, design: .rounded)).foregroundColor(.secondary.opacity(0.6))) \(Text(displayComponents[1]).font(.system(.caption, design: .rounded)).foregroundColor(.secondary)) \(Text("›").font(.system(.caption, design: .rounded)).foregroundColor(.secondary.opacity(0.6))) \(Text(displayComponents[2]).font(.system(.caption, design: .rounded)).foregroundColor(.primary))")
            case 4:
                Text("\(Text(displayComponents[0]).font(.system(.caption, design: .rounded)).foregroundColor(.secondary)) \(Text("›").font(.system(.caption, design: .rounded)).foregroundColor(.secondary.opacity(0.6))) \(Text(displayComponents[1]).font(.system(.caption, design: .rounded)).foregroundColor(.secondary)) \(Text("›").font(.system(.caption, design: .rounded)).foregroundColor(.secondary.opacity(0.6))) \(Text(displayComponents[2]).font(.system(.caption, design: .rounded)).foregroundColor(.secondary)) \(Text("›").font(.system(.caption, design: .rounded)).foregroundColor(.secondary.opacity(0.6))) \(Text(displayComponents[3]).font(.system(.caption, design: .rounded)).foregroundColor(.primary))")
            default:
                Text("")
            }
        }
        .lineLimit(1)
        .truncationMode(.middle)
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
                    Text("Last Modified:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastModifiedString)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .font(.system(.footnote, design: .rounded))
                
                if !state.renderedDocument.metadata.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isMetadataExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                                Text("Metadata")
                                    .font(.system(.footnote, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .rotationEffect(.degrees(isMetadataExpanded ? 90 : 0))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        
                        if isMetadataExpanded {
                            VStack(spacing: 6) {
                                let sortedKeys = state.renderedDocument.metadata.keys.sorted()
                                let showAll = self.showAllMetadata || sortedKeys.count <= 4
                                let visibleKeys = showAll ? sortedKeys : Array(sortedKeys.prefix(4))
                                
                                ForEach(visibleKeys, id: \.self) { key in
                                    HStack(alignment: .top) {
                                        Text(key)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                        Spacer()
                                        Text(state.renderedDocument.metadata[key] ?? "")
                                            .fontWeight(.medium)
                                            .multilineTextAlignment(.trailing)
                                            .lineLimit(3)
                                    }
                                    .font(.system(.footnote, design: .rounded))
                                }
                                
                                if sortedKeys.count > 4 {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showAllMetadata.toggle()
                                        }
                                    }) {
                                        Text(showAllMetadata ? "Show Less" : "Show \(sortedKeys.count - 4) More…")
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 2)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(12)
            .modifier(StatsHUDBackgroundModifier())
            .padding()
        }
    }

    private var persistentRecentFiles: [URL] {
        recentFilesRaw.split(separator: "|").compactMap { URL(string: String($0)) }
    }

    private var lastModifiedString: String {
        guard let date = state.renderedDocument.modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func addToRecentFiles(_ url: URL) {
        let standardURL = url.resolvingSymlinksInPath()
        
        // 1. Update persistent storage (always move to top for next launch)
        var persistent = persistentRecentFiles.map { $0.resolvingSymlinksInPath() }.filter { $0 != standardURL }
        persistent.insert(standardURL, at: 0)
        if persistent.count > 5 {
            persistent = Array(persistent.prefix(5))
        }
        recentFilesRaw = persistent.map { $0.absoluteString }.joined(separator: "|")
        
        // 2. Update session recents for active UI (do not re-order if already present)
        if !sessionRecentFiles.contains(standardURL) {
            sessionRecentFiles.insert(standardURL, at: 0)
            if sessionRecentFiles.count > 5 {
                sessionRecentFiles = Array(sessionRecentFiles.prefix(5))
            }
        }
    }

    private func updateStyle() {
        state.reloadForStyle(
            appearance: selectedAppearance,
            font: selectedFont,
            fontSize: selectedFontSize,
            spacing: selectedSpacing,
            currentURL: nil
        )
    }

    private func copyMarkdown() {
        guard !state.renderedDocument.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(state.renderedDocument.rawMarkdown, forType: .string)
    }

    private func loadOpenedFile() {
        guard let openedFile else {
            state.clear()
            return
        }
        let standardizedURL = openedFile.standardizedFileURL
        let targetURL = BookmarkManager.resolveBookmark(for: standardizedURL) ?? standardizedURL
        state.load(url: targetURL, appearance: selectedAppearance, font: selectedFont, fontSize: selectedFontSize, spacing: selectedSpacing)
        
        // Industry-standard recent documents sorting behavior:
        // Do not instantly re-sort the sidebar list if the document is already in the recents list.
        // This avoids layout jumping under the cursor. It will be sorted on next app launch or when a new file is added.
        addToRecentFiles(targetURL)
        
        if openedFile != standardizedURL {
            DispatchQueue.main.async {
                self.openedFile = standardizedURL
            }
        }
    }

    private func loadDroppedFile(from providers: [NSItemProvider]) async -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        guard let url = await loadFileURL(from: provider) else {
            return false
        }

        let standardizedURL = url.standardizedFileURL
        BookmarkManager.saveBookmark(for: standardizedURL)
        await MainActor.run {
            openedFile = standardizedURL
        }
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

    private var typographyPopoverContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Typography & Style")
                .font(.system(.headline, design: .rounded))
                .padding(.bottom, 2)
            
            HStack {
                Text("Font Family")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("Font Family", selection: $selectedFont) {
                    ForEach(PreviewFont.allCases) { font in
                        Text(font.displayName).tag(font)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            HStack {
                Text("Spacing Density")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("Spacing Density", selection: $selectedSpacing) {
                    ForEach(PreviewSpacing.allCases) { spacing in
                        Text(spacing.displayName).tag(spacing)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            Divider()
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Font Size")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(selectedFontSize)) px")
                        .font(.system(.subheadline, design: .rounded))
                        .monospacedDigit()
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $selectedFontSize, in: 10...28, step: 1)
                        .controlSize(.small)
                    
                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 285)
    }

    private func bottomFooter(for url: URL) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                
                breadcrumbView(for: url)
            }
            .layoutPriority(0)
            
            Spacer()
            
            // Slider to increase/decrease font size
            HStack(spacing: 8) {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Slider(value: $selectedFontSize, in: 10...28, step: 1)
                    .controlSize(.small)
                    .frame(width: 120)
                
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .frame(maxHeight: 38)
        .lineLimit(1)
        .background(.bar)
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
    let openMarkdownFile: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Open a Markdown File", systemImage: "doc.richtext")
        } description: {
            Text("Use File > Open, drop a .md file here, or preview from Finder with Space.")
        } actions: {
            Button("Open File...", action: openMarkdownFile)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView(openedFile: .constant(nil), openMarkdownFile: {})
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
