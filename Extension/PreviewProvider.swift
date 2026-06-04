import Foundation
@preconcurrency import QuickLookUI
import UniformTypeIdentifiers
import Markdown

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let title = request.fileURL.deletingPathExtension().lastPathComponent
        let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let resolvedAppearance: MarkdownAppearance = isDark ? .dark : .light
        nonisolated(unsafe) let sendableHandler = handler

        DispatchQueue.global(qos: .userInitiated).async {

            let result: MarkdownRenderResult

            do {
                let fileURL = request.fileURL
                let resolvedURL = BookmarkManager.resolveBookmark(for: fileURL) ?? fileURL
                let hasScopedAccess = resolvedURL.startAccessingSecurityScopedResource()
                defer {
                    if hasScopedAccess {
                        resolvedURL.stopAccessingSecurityScopedResource()
                    }
                }

                let markdown = try MarkdownDocumentLoader.load(url: resolvedURL)

                let (bodyHTML, headings) = MarkdownRenderer.renderBody(markdown: markdown, baseURL: resolvedURL.deletingLastPathComponent())
                let metadata = MarkdownRenderer.parseFrontMatter(markdown).metadata

                result = MarkdownRenderer.wrapHTML(
                    title: title,
                    bodyHTML: bodyHTML,
                    metadata: metadata,
                    headings: headings,
                    appearance: resolvedAppearance
                )
            } catch {
                result = MarkdownRenderer.renderError(
                    title: title,
                    message: error.localizedDescription
                )
            }

            let html = result.html
            let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 1200)) { _ in
                guard let data = html.data(using: .utf8) else {
                    throw PeekMarkError.htmlEncodingFailed
                }
                return data
            }
            reply.title = result.title
            sendableHandler(reply, nil)
        }
    }
}
