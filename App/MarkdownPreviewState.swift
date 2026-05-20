import Foundation
import SwiftUI

struct RenderedDocument {
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

@MainActor
@Observable
final class MarkdownPreviewState {
    var renderedDocument: RenderedDocument = .empty
    var renderGeneration: Int = 0

    func load(url: URL, appearance: MarkdownAppearance = .system) {
        renderGeneration += 1
        let generation = renderGeneration

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let document = RenderedDocument.load(from: url, appearance: appearance)
            await MainActor.run {
                guard self.renderGeneration == generation else { return }
                self.renderedDocument = document
            }
        }
    }

    func clear() {
        renderedDocument = .empty
        renderGeneration += 1
    }

    func reloadForAppearance(_ appearance: MarkdownAppearance, currentURL: URL?) {
        renderGeneration += 1
        if currentURL == nil {
            renderedDocument = renderedDocument.withAppearance(appearance)
        }
    }
}