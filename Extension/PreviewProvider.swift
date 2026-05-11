import Foundation
import QuickLookUI
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let title = request.fileURL.deletingPathExtension().lastPathComponent
        let result: MarkdownRenderResult

        do {
            let markdown = try MarkdownDocumentLoader.load(url: request.fileURL)
            result = MarkdownRenderer.render(
                markdown: markdown,
                title: title,
                baseURL: request.fileURL.deletingLastPathComponent()
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
        handler(reply, nil)
    }
}
