import Foundation
import Markdown

struct MarkdownRenderResult {
    let title: String
    let html: String
    let bodyHTML: String
}

enum MarkdownRenderer {
    static func render(
        markdown: String,
        title: String,
        baseURL: URL? = nil,
        appearance: MarkdownAppearance = .light
    ) -> MarkdownRenderResult {
        let bodyHTML = renderBody(markdown: markdown, baseURL: baseURL)
        return wrapHTML(title: title, bodyHTML: bodyHTML, appearance: appearance)
    }

    static func renderError(
        title: String,
        message: String,
        appearance: MarkdownAppearance = .light
    ) -> MarkdownRenderResult {
        let escapedMessage = HTMLSanitizer.escape(message)
        let body = """
        <h1>\(HTMLSanitizer.escape(title))</h1>
        <blockquote>\(escapedMessage)</blockquote>
        """
        return wrapHTML(title: title, bodyHTML: body, appearance: appearance)
    }

    static func renderBody(markdown: String, baseURL: URL? = nil) -> String {
        let document = Document(parsing: markdown)
        let body = HTMLSanitizer.sanitizeGeneratedHTML(HTMLFormatter.format(document))
        return embedLocalImages(in: body, baseURL: baseURL)
    }

    static func wrapHTML(title: String, bodyHTML: String, appearance: MarkdownAppearance) -> MarkdownRenderResult {
        let escapedTitle = HTMLSanitizer.escape(title)
        return MarkdownRenderResult(
            title: title,
            html: documentHTML(title: escapedTitle, body: bodyHTML, appearance: appearance),
            bodyHTML: bodyHTML
        )
    }

    private static func documentHTML(title: String, body: String, appearance: MarkdownAppearance) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title)</title>
          <style>
        \(PeekMarkTheme.css(for: appearance))
          </style>
        </head>
        <body>
          <main>
        \(body)
          </main>
        </body>
        </html>
        """
    }

    private static func embedLocalImages(in html: String, baseURL: URL?) -> String {
        guard let baseURL else {
            return html
        }
        return LocalImageDataURIRewriter.rewrite(html: html, baseDirectory: baseURL)
    }
}

private enum LocalImageDataURIRewriter {
    private static let supportedMimeTypes = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "webp": "image/webp"
    ]

    static func rewrite(
        html: String,
        baseDirectory: URL,
        byteLimit: Int = 4 * 1024 * 1024,
        aggregateByteLimit: Int = 12 * 1024 * 1024
    ) -> String {
        let nsHTML = html as NSString
        guard let regex = try? NSRegularExpression(pattern: #"(<img\b[^>]*?\bsrc=")([^"]*)(")"#, options: [.caseInsensitive]) else {
            return html
        }
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        guard !matches.isEmpty else {
            return html
        }

        var chunks: [String] = []
        chunks.reserveCapacity(matches.count * 2 + 1)
        var cursor = 0
        var embeddedBytes = 0
        for match in matches {
            chunks.append(nsHTML.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            let prefix = nsHTML.substring(with: match.range(at: 1))
            let source = nsHTML.substring(with: match.range(at: 2))
            let suffix = nsHTML.substring(with: match.range(at: 3))
            if let image = dataURI(for: source, baseDirectory: baseDirectory, byteLimit: byteLimit),
               embeddedBytes + image.byteCount <= aggregateByteLimit {
                embeddedBytes += image.byteCount
                chunks.append(prefix)
                chunks.append(image.uri)
                chunks.append(suffix)
            } else if resolvedURL(for: source, baseDirectory: baseDirectory) != nil {
                chunks.append(prefix)
                chunks.append(suffix)
            } else if shouldStripImageSource(source) {
                chunks.append(prefix)
                chunks.append(suffix)
            } else {
                chunks.append(nsHTML.substring(with: match.range))
            }
            cursor = match.range.location + match.range.length
        }
        chunks.append(nsHTML.substring(from: cursor))
        return chunks.joined()
    }

    private static func dataURI(for source: String, baseDirectory: URL, byteLimit: Int) -> (uri: String, byteCount: Int)? {
        guard let url = resolvedURL(for: source, baseDirectory: baseDirectory) else {
            return nil
        }
        let ext = url.pathExtension.lowercased()
        guard let mimeType = supportedMimeTypes[ext] else {
            return nil
        }
        guard isRegularFileWithinLimit(url: url, byteLimit: byteLimit) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url), data.count <= byteLimit else {
            return nil
        }
        return ("data:\(mimeType);base64,\(data.base64EncodedString())", data.count)
    }

    private static func resolvedURL(for source: String, baseDirectory: URL) -> URL? {
        guard !source.isEmpty, !source.hasPrefix("#"), !source.hasPrefix("/") else {
            return nil
        }
        guard !source.contains(":") else {
            return nil
        }
        let decoded = source.removingPercentEncoding ?? source
        let baseURL = baseDirectory.resolvingSymlinksInPath().standardizedFileURL
        let candidate = URL(fileURLWithPath: decoded, relativeTo: baseURL)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard isSubpath(candidate.path, of: baseURL.path) else {
            return nil
        }
        return candidate
    }

    private static func isRegularFileWithinLimit(url: URL, byteLimit: Int) -> Bool {
        guard
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
            values.isRegularFile == true,
            let fileSize = values.fileSize,
            fileSize <= byteLimit
        else {
            return false
        }
        return true
    }

    private static func isSubpath(_ childPath: String, of basePath: String) -> Bool {
        childPath == basePath || childPath.hasPrefix(basePath + "/")
    }

    private static func shouldStripImageSource(_ source: String) -> Bool {
        guard let scheme = URL(string: source)?.scheme?.lowercased() else {
            return false
        }
        return scheme != "data"
    }
}
