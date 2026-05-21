import Foundation
import Markdown

struct MarkdownRenderResult {
    let title: String
    let html: String
    let bodyHTML: String
    let metadata: [String: String]
}

enum MarkdownRenderer {
    static func render(
        markdown: String,
        title: String,
        baseURL: URL? = nil,
        appearance: MarkdownAppearance = .light,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular
    ) -> MarkdownRenderResult {
        let (metadata, content) = parseFrontMatter(markdown)
        let bodyHTML = renderBody(markdown: content, baseURL: baseURL)
        return wrapHTML(title: title, bodyHTML: bodyHTML, metadata: metadata, appearance: appearance, font: font, fontSize: fontSize, spacing: spacing)
    }

    static func renderError(
        title: String,
        message: String,
        appearance: MarkdownAppearance = .light,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular
    ) -> MarkdownRenderResult {
        let escapedMessage = HTMLSanitizer.escape(message)
        let body = """
        <h1>\(HTMLSanitizer.escape(title))</h1>
        <blockquote>\(escapedMessage)</blockquote>
        """
        return wrapHTML(title: title, bodyHTML: body, metadata: [:], appearance: appearance, font: font, fontSize: fontSize, spacing: spacing)
    }

    static func parseFrontMatter(_ markdown: String) -> (metadata: [String: String], content: String) {
        let lines = markdown.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return ([:], markdown)
        }
        
        var metadata: [String: String] = [:]
        var contentStartLineIndex = -1
        
        for i in 1..<lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                contentStartLineIndex = i + 1
                break
            }
            
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0) }
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                metadata[key] = value
            }
        }
        
        if contentStartLineIndex != -1 {
            let contentLines = lines.suffix(from: contentStartLineIndex)
            return (metadata, contentLines.joined(separator: "\n"))
        } else {
            return ([:], markdown)
        }
    }

    static func renderBody(markdown: String, baseURL: URL? = nil) -> String {
        let document = Document(parsing: markdown)
        let body = HTMLSanitizer.sanitizeGeneratedHTML(HTMLFormatter.format(document))
        return embedLocalImages(in: body, baseURL: baseURL)
    }

    static func wrapHTML(
        title: String,
        bodyHTML: String,
        metadata: [String: String],
        appearance: MarkdownAppearance,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular
    ) -> MarkdownRenderResult {
        let escapedTitle = HTMLSanitizer.escape(title)
        return MarkdownRenderResult(
            title: title,
            html: documentHTML(title: escapedTitle, body: bodyHTML, appearance: appearance, font: font, fontSize: fontSize, spacing: spacing),
            bodyHTML: bodyHTML,
            metadata: metadata
        )
    }

    private static func documentHTML(
        title: String,
        body: String,
        appearance: MarkdownAppearance,
        font: PreviewFont,
        fontSize: Double,
        spacing: PreviewSpacing
    ) -> String {
        let highlightCSSLink: String
        switch appearance {
        case .system:
            highlightCSSLink = """
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
            """
        case .light:
            highlightCSSLink = """
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
            """
        case .dark:
            highlightCSSLink = """
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css">
            """
        }

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title)</title>
          
          <!-- Highlight.js for Syntax Highlighting -->
          \(highlightCSSLink)
          <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
          
          <!-- KaTeX for LaTeX Render -->
          <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
          <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
          <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"></script>

          <style>
        \(PeekMarkTheme.css(for: appearance, font: font, fontSize: fontSize, spacing: spacing))
          
          /* Customized math and code layouts */
          .mermaid {
            background: var(--code-bg);
            border: 1px solid var(--soft-line);
            border-radius: 6px;
            padding: 16px;
            margin: 0 0 var(--paragraph-margin);
            display: flex;
            justify-content: center;
          }
          pre code.hljs {
            background: var(--code-bg);
            border-radius: 4px;
            padding: 0;
          }
          pre {
            background: var(--code-bg) !important;
          }
          code:not(.hljs) {
            background: var(--code-bg);
          }
          </style>
        </head>
        <body>
          <main>
        \(body)
          </main>

          <script>
            // Convert Mermaid code blocks
            document.querySelectorAll('pre code.language-mermaid').forEach(function(codeBlock) {
                var pre = codeBlock.parentNode;
                var div = document.createElement('div');
                div.className = 'mermaid';
                div.textContent = codeBlock.textContent;
                pre.parentNode.replaceChild(div, pre);
            });

            // Run Highlight.js
            hljs.highlightAll();

            // Run KaTeX auto-render
            renderMathInElement(document.body, {
                delimiters: [
                    {left: '$$', right: '$$', display: true},
                    {left: '$', right: '$', display: false},
                    {left: '\\\\(', right: '\\\\)', display: false},
                    {left: '\\\\[', right: '\\\\]', display: true}
                ],
                throwOnError : false
            });
          </script>

          <!-- Load Mermaid ESM -->
          <script type="module">
            import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
            mermaid.initialize({
              startOnLoad: true,
              theme: 'dark',
              securityLevel: 'loose'
            });
          </script>
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
