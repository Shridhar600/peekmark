import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var openedFile: URL?
    let openDocument: () -> Void

    @State private var state = MarkdownPreviewState()

    var body: some View {
        contentView
            .frame(minWidth: 620, idealWidth: 860, minHeight: 480, idealHeight: 720)
            .navigationTitle(state.renderedDocument.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: openDocument) {
                        Label("Open", systemImage: "doc.badge.plus")
                    }
                    .help("Open Markdown File (⌘O)")
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

    @ViewBuilder
    private var contentView: some View {
        if state.renderedDocument.isEmpty {
            EmptyStateView()
        } else {
            MarkdownPreviewView(html: state.renderedDocument.html)
        }
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

#Preview {
    ContentView(openedFile: .constant(nil), openDocument: {})
}