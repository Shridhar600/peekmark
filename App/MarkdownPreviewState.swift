import Foundation
import SwiftUI

struct RenderedDocument: Sendable {
    let title: String
    let html: String
    let bodyHTML: String
    let rawMarkdown: String
    let headings: [HeadingItem]

    var isEmpty: Bool {
        html.isEmpty
    }

    static let empty = RenderedDocument(title: "PeekMark", html: "", bodyHTML: "", rawMarkdown: "", headings: [])

    static func load(from url: URL, appearance: MarkdownAppearance = .light) -> RenderedDocument {
        let title = url.deletingPathExtension().lastPathComponent

        do {
            let (markdown, result) = try MarkdownDocumentLoader.withSecurityScopedAccess(to: url) {
                let markdown = try MarkdownDocumentLoader.load(url: url)
                let renderResult = MarkdownRenderer.render(
                    markdown: markdown,
                    title: title,
                    baseURL: url.deletingLastPathComponent(),
                    appearance: appearance
                )
                return (markdown, renderResult)
            }
            let headings = HeadingExtractor.extract(from: markdown)
            return RenderedDocument(
                title: result.title,
                html: result.html,
                bodyHTML: result.bodyHTML,
                rawMarkdown: markdown,
                headings: headings
            )
        } catch {
            let result = MarkdownRenderer.renderError(
                title: title,
                message: error.localizedDescription,
                appearance: appearance
            )
            return RenderedDocument(
                title: result.title,
                html: result.html,
                bodyHTML: result.bodyHTML,
                rawMarkdown: "",
                headings: []
            )
        }
    }

    func withAppearance(_ appearance: MarkdownAppearance) -> RenderedDocument {
        guard !bodyHTML.isEmpty else {
            return self
        }
        let result = MarkdownRenderer.wrapHTML(title: title, bodyHTML: bodyHTML, appearance: appearance)
        return RenderedDocument(
            title: result.title,
            html: result.html,
            bodyHTML: result.bodyHTML,
            rawMarkdown: rawMarkdown,
            headings: headings
        )
    }
}

@MainActor
@Observable
final class MarkdownPreviewState {
    var renderedDocument: RenderedDocument = .empty
    var renderGeneration: Int = 0

    var wordCount: Int {
        let text = renderedDocument.rawMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return 0 }
        let charSet = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let components = text.components(separatedBy: charSet)
        return components.filter { !$0.isEmpty }.count
    }

    var characterCount: Int {
        renderedDocument.rawMarkdown.count
    }

    var readingTimeMinutes: Int {
        let words = wordCount
        guard words > 0 else { return 0 }
        return max(1, Int(ceil(Double(words) / 200.0)))
    }

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