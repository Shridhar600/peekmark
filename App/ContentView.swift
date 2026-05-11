import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var openedFile: URL?
    let openDocument: () -> Void

    @State private var renderedDocument = RenderedDocument.empty
    @AppStorage("markdownAppearance") private var appearance = MarkdownAppearance.system

    var body: some View {
        ZStack {
            if renderedDocument.isEmpty {
                EmptyStateView()
                    .transition(.opacity)
            } else {
                MarkdownPreviewView(html: renderedDocument.html)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 620, idealWidth: 860, minHeight: 480, idealHeight: 720)
        .navigationTitle(renderedDocument.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: openDocument) {
                    Label("Open Markdown", systemImage: "doc.badge.plus")
                }
                .help("Open Markdown")

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

private struct AppearanceToolbarPicker: View {
    @Binding var appearance: MarkdownAppearance

    var body: some View {
        Picker("Appearance", selection: $appearance) {
            Label("System", systemImage: "circle.lefthalf.filled")
                .tag(MarkdownAppearance.system)
            Label("Light", systemImage: "sun.max.fill")
                .tag(MarkdownAppearance.light)
            Label("Dark", systemImage: "moon.fill")
                .tag(MarkdownAppearance.dark)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 126)
        .help("Preview Appearance")
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
