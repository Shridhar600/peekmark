import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var openedFile: URL?
    let openDocument: () -> Void

    @State private var renderedDocument = RenderedDocument.empty
    @State private var renderGeneration = 0
    @AppStorage("markdownAppearance") private var appearance = MarkdownAppearance.system

    var body: some View {
        contentView
            .frame(minWidth: 620, idealWidth: 860, minHeight: 480, idealHeight: 720)
            .navigationTitle(renderedDocument.title)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: openDocument) {
                        Label("Open Markdown", systemImage: "doc.badge.plus")
                    }
                    .help("Open Markdown")

                    AppearanceToolbarMenu(appearance: $appearance)
                }
            }
            .toolbar(removing: .title)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .onAppear(perform: loadOpenedFile)
            .onChange(of: openedFile) {
                loadOpenedFile()
            }
            .onChange(of: appearance) {
                reloadForAppearanceChange()
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                loadDroppedFile(from: providers)
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if renderedDocument.isEmpty {
            EmptyStateView()
        } else {
            MarkdownPreviewView(html: renderedDocument.html)
        }
    }

    private func loadOpenedFile() {
        renderGeneration += 1
        let generation = renderGeneration

        guard let openedFile else {
            renderedDocument = .empty
            return
        }

        let currentAppearance = appearance
        Task.detached(priority: .userInitiated) {
            let document = RenderedDocument.load(from: openedFile, appearance: currentAppearance)
            await MainActor.run {
                guard renderGeneration == generation else {
                    return
                }
                renderedDocument = document
            }
        }
    }

    private func loadDroppedFile(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard
                let data = item as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            else {
                return
            }
            Task { @MainActor in
                openedFile = url
            }
        }
        return true
    }

    private func reloadForAppearanceChange() {
        guard openedFile != nil else {
            renderGeneration += 1
            renderedDocument = renderedDocument.withAppearance(appearance)
            return
        }
        loadOpenedFile()
    }
}

private struct AppearanceToolbarMenu: View {
    @Binding var appearance: MarkdownAppearance

    var body: some View {
        Menu {
            ForEach(MarkdownAppearance.allCases) { mode in
                Button {
                    appearance = mode
                } label: {
                    Label(mode.accessibilityLabel, systemImage: appearance == mode ? "checkmark" : mode.symbolName)
                }
            }
        } label: {
            Label("Preview Appearance", systemImage: appearance.symbolName)
        }
        .help("Preview Appearance")
    }
}

extension MarkdownAppearance {
    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .system: return "System appearance"
        case .light: return "Light mode"
        case .dark: return "Dark mode"
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("Open a Markdown File")
                .font(.title2.weight(.semibold))

            Text("Use File > Open, drop a .md file here, or preview from Finder with Space.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(36)
        .frame(maxWidth: 420)
    }
}

private struct RenderedDocument {
    let title: String
    let html: String
    let bodyHTML: String

    var isEmpty: Bool {
        html.isEmpty
    }

    static let empty = RenderedDocument(title: "PeekMark", html: "", bodyHTML: "")

    static func load(from url: URL, appearance: MarkdownAppearance = .light) -> RenderedDocument {
        let title = url.deletingPathExtension().lastPathComponent

        do {
            let result = try MarkdownDocumentLoader.withSecurityScopedAccess(to: url) {
                let markdown = try MarkdownDocumentLoader.load(url: url)
                return MarkdownRenderer.render(
                    markdown: markdown,
                    title: title,
                    baseURL: url.deletingLastPathComponent(),
                    appearance: appearance
                )
            }
            return RenderedDocument(title: result.title, html: result.html, bodyHTML: result.bodyHTML)
        } catch {
            let result = MarkdownRenderer.renderError(
                title: title,
                message: error.localizedDescription,
                appearance: appearance
            )
            return RenderedDocument(title: result.title, html: result.html, bodyHTML: result.bodyHTML)
        }
    }

    func withAppearance(_ appearance: MarkdownAppearance) -> RenderedDocument {
        guard !bodyHTML.isEmpty else {
            return self
        }
        let result = MarkdownRenderer.wrapHTML(title: title, bodyHTML: bodyHTML, appearance: appearance)
        return RenderedDocument(title: result.title, html: result.html, bodyHTML: result.bodyHTML)
    }
}
