import os
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private enum SidebarItem: Hashable {
        case preview
    }

    @Binding var openedFile: URL?
    let openMarkdownFile: () -> Void

    @State private var state = MarkdownPreviewState()
    @State private var pinboard = PinboardStore()
    @State private var selection: SidebarItem? = .preview
    @State private var searchText = ""
    @State private var scrollToHeaderIndex: Int?

    // Typography popover toggle
    @State private var showTypographyPopover = false
    // Document-detail popover toggle (the stats previously shown in the sidebar)
    @State private var showInfoPopover = false

    @State private var sessionRecentFiles: [URL] = []
    @AppStorage("recentFiles") private var recentFilesRaw: String = ""
    @AppStorage("previewFont") private var selectedFont: PreviewFont = .system
    @AppStorage("previewSpacing") private var selectedSpacing: PreviewSpacing = .compact
    @AppStorage("previewFontSize") private var selectedFontSize: Double = 14.5
    @AppStorage("previewAppearance") private var selectedAppearance: MarkdownAppearance = .system
    @Environment(\.colorScheme) private var colorScheme

    private struct StyleSettings: Equatable {
        let appearance: MarkdownAppearance
        let font: PreviewFont
        let fontSize: Double
        let spacing: PreviewSpacing
        let colorScheme: ColorScheme
    }

    private var styleSettings: StyleSettings {
        StyleSettings(
            appearance: selectedAppearance,
            font: selectedFont,
            fontSize: selectedFontSize,
            spacing: selectedSpacing,
            colorScheme: colorScheme
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                openedFile: $openedFile,
                sessionRecentFiles: $sessionRecentFiles,
                recentFilesRaw: $recentFilesRaw,
                pinboard: pinboard
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, idealWidth: 1020, minHeight: 520, idealHeight: 780)
        .searchable(text: $searchText, prompt: "Search in document...")
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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

                Button(action: { showInfoPopover.toggle() }) {
                    Label("Document Info", systemImage: "info.circle")
                }
                .help("Document details")
                .disabled(state.renderedDocument.isEmpty)
                .popover(isPresented: $showInfoPopover, arrowEdge: .bottom) {
                    StatsHUDView(state: state)
                        .frame(width: 280)
                        .padding(12)
                }

                Button(action: { showTypographyPopover.toggle() }) {
                    Label("Text Style", systemImage: "textformat.size")
                }
                .keyboardShortcut("t", modifiers: .command)
                .help("Adjust preview layout and typography")
                .popover(isPresented: $showTypographyPopover, arrowEdge: .bottom) {
                    TypographyPopoverView(
                        selectedFont: $selectedFont,
                        selectedSpacing: $selectedSpacing,
                        selectedFontSize: $selectedFontSize
                    )
                }
            }
        }
        .onAppear {
            selectedAppearance = .system
            sessionRecentFiles = persistentRecentFiles
            loadOpenedFile()
        }
        .onChange(of: openedFile) { _, _ in
            loadOpenedFile()
        }
        .onChange(of: styleSettings) { _, _ in
            updateStyle()
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            Task {
                _ = await loadDroppedFile(from: providers)
            }
            return true
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
                    bodyHTML: state.renderedDocument.bodyHTML,
                    html: state.renderedDocument.html,
                    appearance: selectedAppearance,
                    font: selectedFont,
                    fontSize: selectedFontSize,
                    spacing: selectedSpacing,
                    searchText: searchText,
                    scrollToHeaderIndex: $scrollToHeaderIndex,
                    documentTitle: state.renderedDocument.title
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let url = openedFile {
                    BottomFooterView(url: url, selectedFontSize: $selectedFontSize)
                }
            }
            .navigationTitle(state.renderedDocument.title)
        }
    }

    private var persistentRecentFiles: [URL] {
        recentFilesRaw.split(separator: "|").compactMap { string in
            let str = String(string)
            if str.hasPrefix("file://") {
                return URL(string: str)
            } else {
                return URL(fileURLWithPath: str)
            }
        }
    }

    private func addToRecentFiles(_ url: URL) {
        let standardURL = url.resolvingSymlinksInPath()
        
        // 1. Update persistent storage (always move to top for next launch)
        var persistent = persistentRecentFiles.filter { $0 != standardURL }
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
            Task { @MainActor in
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
        // Only open Markdown files via drop — ignore folders and other types.
        // (Folders are organized by dropping onto a collection, not opened here.)
        let isDirectory = (try? standardizedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let ext = standardizedURL.pathExtension.lowercased()
        guard !isDirectory, ext == "md" || ext == "markdown" else {
            return false
        }
        BookmarkManager.saveBookmark(for: standardizedURL)
        await MainActor.run {
            openedFile = standardizedURL
        }
        return true
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            let flag = OSAllocatedUnfairLock(initialState: false)

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                flag.withLock { hasResumed in
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: nil)
                    }
                }
            }

            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let data = item as? Data
                timeoutTask.cancel()
                flag.withLock { hasResumed in
                    if !hasResumed {
                        hasResumed = true
                        if let data,
                           let url = URL(dataRepresentation: data, relativeTo: nil) {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
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
