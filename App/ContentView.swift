import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var openedFile: URL?
    let openDocument: () -> Void

    @State private var renderedDocument = RenderedDocument.empty
    @AppStorage("markdownAppearance") private var appearance = MarkdownAppearance.system

    var body: some View {
        contentView
            .frame(minWidth: 620, idealWidth: 860, minHeight: 480, idealHeight: 720)
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    OpenFileButton(action: openDocument)
                    AppearanceToolbarPicker(appearance: $appearance)
                }
            }
            .onAppear(perform: loadOpenedFile)
            .onChange(of: openedFile) {
                loadOpenedFile()
            }
            .onChange(of: appearance) {
                renderedDocument = renderedDocument.withAppearance(appearance)
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
        guard let openedFile else {
            renderedDocument = .empty
            return
        }
        renderedDocument = RenderedDocument.load(from: openedFile, appearance: appearance)
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
}

private struct OpenFileButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                Text("Open")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
        .help("Open Markdown")
    }
}

private struct AppearanceToolbarPicker: View {
    @Binding var appearance: MarkdownAppearance

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(MarkdownAppearance.allCases.enumerated()), id: \.element.id) { index, mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appearance = mode
                    }
                } label: {
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(appearance == mode ? Color.primary : Color.secondary)
                        .frame(width: 30, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(mode.accessibilityLabel)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appearance = mode
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .background(
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor))
        )
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
        case .dark: return "dark mode"
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
            let markdown = try MarkdownDocumentLoader.load(url: url)
            let result = MarkdownRenderer.render(
                markdown: markdown,
                title: title,
                baseURL: url.deletingLastPathComponent(),
                appearance: appearance
            )
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
