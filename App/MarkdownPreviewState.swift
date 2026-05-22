import Foundation
import SwiftUI

struct RenderedDocument: Sendable {
    let title: String
    let html: String
    let bodyHTML: String
    let rawMarkdown: String
    let headings: [HeadingItem]
    let modificationDate: Date?
    let fileURL: URL?
    let metadata: [String: String]

    var isEmpty: Bool {
        html.isEmpty
    }

    static let empty = RenderedDocument(title: "PeekMark", html: "", bodyHTML: "", rawMarkdown: "", headings: [], modificationDate: nil, fileURL: nil, metadata: [:])

    static func load(
        from url: URL,
        appearance: MarkdownAppearance = .light,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular,
        isTransparent: Bool = false
    ) -> RenderedDocument {
        let title = url.deletingPathExtension().lastPathComponent

        do {
            let (markdown, result, modificationDate) = try MarkdownDocumentLoader.withSecurityScopedAccess(to: url) { resolvedURL in
                let modDate = try? resolvedURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                let markdown = try MarkdownDocumentLoader.load(url: resolvedURL)
                let renderResult = MarkdownRenderer.render(
                    markdown: markdown,
                    title: title,
                    baseURL: resolvedURL.deletingLastPathComponent(),
                    appearance: appearance,
                    font: font,
                    fontSize: fontSize,
                    spacing: spacing,
                    isTransparent: isTransparent
                )
                return (markdown, renderResult, modDate)
            }
            let headings = HeadingExtractor.extract(from: markdown)
            return RenderedDocument(
                title: result.title,
                html: result.html,
                bodyHTML: result.bodyHTML,
                rawMarkdown: markdown,
                headings: headings,
                modificationDate: modificationDate,
                fileURL: url,
                metadata: result.metadata
            )
        } catch {
            let result = MarkdownRenderer.renderError(
                title: title,
                message: error.localizedDescription,
                appearance: appearance,
                font: font,
                fontSize: fontSize,
                spacing: spacing,
                isTransparent: isTransparent
            )
            return RenderedDocument(
                title: result.title,
                html: result.html,
                bodyHTML: result.bodyHTML,
                rawMarkdown: "",
                headings: [],
                modificationDate: nil,
                fileURL: url,
                metadata: [:]
            )
        }
    }

    func withStyle(
        appearance: MarkdownAppearance,
        font: PreviewFont,
        fontSize: Double,
        spacing: PreviewSpacing,
        isTransparent: Bool = false
    ) -> RenderedDocument {
        guard !bodyHTML.isEmpty else {
            return self
        }
        let result = MarkdownRenderer.wrapHTML(
            title: title,
            bodyHTML: bodyHTML,
            metadata: metadata,
            appearance: appearance,
            font: font,
            fontSize: fontSize,
            spacing: spacing,
            isTransparent: isTransparent
        )
        return RenderedDocument(
            title: result.title,
            html: result.html,
            bodyHTML: result.bodyHTML,
            rawMarkdown: rawMarkdown,
            headings: headings,
            modificationDate: modificationDate,
            fileURL: fileURL,
            metadata: metadata
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

    func load(
        url: URL,
        appearance: MarkdownAppearance = .system,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular
    ) {
        renderGeneration += 1
        let generation = renderGeneration

        let resolvedAppearance: MarkdownAppearance
        if appearance == .system {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            resolvedAppearance = isDark ? .dark : .light
        } else {
            resolvedAppearance = appearance
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let document = RenderedDocument.load(from: url, appearance: resolvedAppearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: true)
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

    func reloadForStyle(
        appearance: MarkdownAppearance,
        font: PreviewFont,
        fontSize: Double,
        spacing: PreviewSpacing,
        currentURL: URL?
    ) {
        renderGeneration += 1
        
        let resolvedAppearance: MarkdownAppearance
        if appearance == .system {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            resolvedAppearance = isDark ? .dark : .light
        } else {
            resolvedAppearance = appearance
        }

        if let currentURL {
            load(url: currentURL, appearance: resolvedAppearance, font: font, fontSize: fontSize, spacing: spacing)
        } else {
            renderedDocument = renderedDocument.withStyle(appearance: resolvedAppearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: true)
        }
    }
}