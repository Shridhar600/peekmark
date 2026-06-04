import Foundation
import Observation
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
    let wordCount: Int
    let characterCount: Int

    var isEmpty: Bool {
        rawMarkdown.isEmpty
    }

    static let empty = RenderedDocument(title: "PeekMark", html: "", bodyHTML: "", rawMarkdown: "", headings: [], modificationDate: nil, fileURL: nil, metadata: [:], wordCount: 0, characterCount: 0)

    static func load(
        from url: URL,
        appearance: MarkdownAppearance = .light,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular,
        isTransparent: Bool = false
    ) async -> RenderedDocument {
        let title = url.deletingPathExtension().lastPathComponent

        do {
            let resolvedURL = BookmarkManager.resolveBookmark(for: url) ?? url
            let hasScopedAccess = resolvedURL.startAccessingSecurityScopedResource()
            defer {
                if hasScopedAccess {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
            }

            let modDate = try? resolvedURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            let markdown = try MarkdownDocumentLoader.load(url: resolvedURL)
            let renderResult = await MarkdownRenderer.render(
                markdown: markdown,
                title: title,
                baseURL: resolvedURL.deletingLastPathComponent(),
                appearance: appearance,
                font: font,
                fontSize: fontSize,
                spacing: spacing,
                isTransparent: isTransparent
            )
            let modificationDate = modDate
            let wordCount = RenderedDocument.calculateWordCount(for: markdown)
            let characterCount = markdown.count

            return RenderedDocument(
                title: renderResult.title,
                html: renderResult.html,
                bodyHTML: renderResult.bodyHTML,
                rawMarkdown: markdown,
                headings: renderResult.headings,
                modificationDate: modificationDate,
                fileURL: url,
                metadata: renderResult.metadata,
                wordCount: wordCount,
                characterCount: characterCount
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
                metadata: [:],
                wordCount: 0,
                characterCount: 0
            )
        }
    }

    fileprivate static func calculateWordCount(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let charSet = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let components = trimmed.components(separatedBy: charSet)
        return components.filter { !$0.isEmpty }.count
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
            headings: headings,
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
            metadata: metadata,
            wordCount: wordCount,
            characterCount: characterCount
        )
    }
}

@MainActor
@Observable
final class MarkdownPreviewState {
    var renderedDocument: RenderedDocument = .empty
    var renderGeneration: Int = 0

    var wordCount: Int {
        renderedDocument.wordCount
    }

    var characterCount: Int {
        renderedDocument.characterCount
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

        let resolvedAppearance = appearance.resolved

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let document = await RenderedDocument.load(from: url, appearance: resolvedAppearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: true)
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
        
        let resolvedAppearance = appearance.resolved

        if let currentURL {
            load(url: currentURL, appearance: resolvedAppearance, font: font, fontSize: fontSize, spacing: spacing)
        } else {
            renderedDocument = renderedDocument.withStyle(appearance: resolvedAppearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: true)
        }
    }
}