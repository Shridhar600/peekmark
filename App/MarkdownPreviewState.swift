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

            // Hold the security scope only for the file read. Rendering works purely
            // on the in-memory markdown string, so we release the scope before the
            // (async) render rather than keeping it open across the await.
            let modDate: Date?
            let markdown: String
            do {
                let hasScopedAccess = resolvedURL.startAccessingSecurityScopedResource()
                defer {
                    if hasScopedAccess {
                        resolvedURL.stopAccessingSecurityScopedResource()
                    }
                }
                modDate = try? resolvedURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                markdown = try MarkdownDocumentLoader.load(url: resolvedURL)
            }

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

    // Hoisted so an 8 MB document doesn't rebuild this set on every load.
    private static let wordSeparators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)

    fileprivate static func calculateWordCount(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let components = trimmed.components(separatedBy: wordSeparators)
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

    // The in-flight document load and the debounced style refresh. Stored so a new
    // request cancels the previous one instead of stacking concurrent renders.
    private var loadTask: Task<Void, Never>?
    private var styleRegenTask: Task<Void, Never>?

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
        // A new document supersedes any in-flight load or pending style refresh.
        loadTask?.cancel()
        styleRegenTask?.cancel()
        renderGeneration += 1
        let generation = renderGeneration

        let resolvedAppearance = appearance.resolved

        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let document = await RenderedDocument.load(from: url, appearance: resolvedAppearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: true)
            await MainActor.run {
                guard self.renderGeneration == generation else { return }
                self.renderedDocument = document
            }
        }
    }

    func clear() {
        loadTask?.cancel()
        styleRegenTask?.cancel()
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
        let resolvedAppearance = appearance.resolved

        if let currentURL {
            load(url: currentURL, appearance: resolvedAppearance, font: font, fontSize: fontSize, spacing: spacing)
            return
        }

        // Pure typography/appearance change on the already-loaded document.
        //
        // The WKWebView updates live via its incremental CSS-variable path (it reads
        // the font/size/spacing/appearance props directly), so we must NOT rebuild the
        // full themed HTML on the main thread here — doing that on every slider step
        // re-inlined the multi-MB vendor JS and janked the drag. Instead we refresh
        // renderedDocument.html OFF the main thread, debounced, purely so a later FULL
        // reload (search / document switch) starts from the current style.
        let current = renderedDocument
        guard !current.bodyHTML.isEmpty else { return }

        styleRegenTask?.cancel()
        styleRegenTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            if Task.isCancelled { return }
            let restyled = await Task.detached {
                current.withStyle(appearance: resolvedAppearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: true)
            }.value
            guard let self, !Task.isCancelled else { return }
            // Only apply if the same document is still shown — never clobber a newer load.
            guard self.renderedDocument.bodyHTML == current.bodyHTML else { return }
            self.renderedDocument = restyled
        }
    }
}