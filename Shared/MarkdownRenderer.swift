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
        spacing: PreviewSpacing = .regular,
        isTransparent: Bool = false
    ) -> MarkdownRenderResult {
        let (metadata, content) = parseFrontMatter(markdown)
        let bodyHTML = renderBody(markdown: content, baseURL: baseURL)
        return wrapHTML(title: title, bodyHTML: bodyHTML, metadata: metadata, appearance: appearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: isTransparent)
    }

    static func renderError(
        title: String,
        message: String,
        appearance: MarkdownAppearance = .light,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular,
        isTransparent: Bool = false
    ) -> MarkdownRenderResult {
        let escapedMessage = HTMLSanitizer.escape(message)
        let body = """
        <h1>\(HTMLSanitizer.escape(title))</h1>
        <blockquote>\(escapedMessage)</blockquote>
        """
        return wrapHTML(title: title, bodyHTML: body, metadata: [:], appearance: appearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: isTransparent)
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
        let (processedMarkdown, footnotesHTML) = processFootnotes(markdown)
        let document = Document(parsing: processedMarkdown)
        let body = HTMLSanitizer.sanitizeGeneratedHTML(HTMLFormatter.format(document))
        let bodyWithImages = embedLocalImages(in: body, baseURL: baseURL)
        return bodyWithImages + footnotesHTML
    }

    private static func processFootnotes(_ markdown: String) -> (processedMarkdown: String, footnotesHTML: String) {
        var processed = markdown
        var footnotes: [(label: String, content: String)] = []
        
        let lines = markdown.components(separatedBy: .newlines)
        var bodyLines: [String] = []
        var currentLabel: String? = nil
        var currentContent = ""
        
        let definitionRegex = try? NSRegularExpression(pattern: "^\\[\\^([^\\]]+)\\]:\\s*(.*)$", options: [])
        
        for line in lines {
            if let regex = definitionRegex,
               let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                if let label = currentLabel {
                    footnotes.append((label, currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                
                let labelRange = match.range(at: 1)
                let contentRange = match.range(at: 2)
                let label = (line as NSString).substring(with: labelRange)
                let content = (line as NSString).substring(with: contentRange)
                
                currentLabel = label
                currentContent = content
            } else if let label = currentLabel {
                if line.hasPrefix("    ") || line.hasPrefix("\t") || line.trimmingCharacters(in: .whitespaces).isEmpty {
                    currentContent += "\n" + line
                } else {
                    footnotes.append((label, currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentLabel = nil
                    currentContent = ""
                    bodyLines.append(line)
                }
            } else {
                bodyLines.append(line)
            }
        }
        if let label = currentLabel {
            footnotes.append((label, currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        processed = bodyLines.joined(separator: "\n")
        
        let refRegex = try? NSRegularExpression(pattern: "\\[\\^([^\\]]+)\\]", options: [])
        if let refRegex = refRegex {
            let nsProcessed = processed as NSString
            let matches = refRegex.matches(in: processed, options: [], range: NSRange(location: 0, length: nsProcessed.length))
            
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let labelRange = match.range(at: 1)
                let label = nsProcessed.substring(with: labelRange)
                
                if footnotes.contains(where: { $0.label == label }) {
                    let htmlRef = "<sup class=\"footnote-ref\" id=\"fnref-\(label)\"><a href=\"#fn-\(label)\">\(label)</a></sup>"
                    processed = (processed as NSString).replacingCharacters(in: fullRange, with: htmlRef)
                }
            }
        }
        
        guard !footnotes.isEmpty else {
            return (processed, "")
        }
        
        var footnotesHTML = "<div class=\"footnotes\">\n<hr>\n<ol>\n"
        for footnote in footnotes {
            let contentDoc = Document(parsing: footnote.content)
            var contentHTML = HTMLFormatter.format(contentDoc)
            
            if contentHTML.hasPrefix("<p>") && contentHTML.hasSuffix("</p>\n") {
                contentHTML = String(contentHTML.dropFirst(3).dropLast(5))
            } else if contentHTML.hasPrefix("<p>") && contentHTML.hasSuffix("</p>") {
                contentHTML = String(contentHTML.dropFirst(3).dropLast(4))
            }
            
            footnotesHTML += "<li id=\"fn-\(footnote.label)\">\(contentHTML) <a href=\"#fnref-\(footnote.label)\" class=\"footnote-backref\">↩</a></li>\n"
        }
        footnotesHTML += "</ol>\n</div>"
        
        return (processed, footnotesHTML)
    }

    static func wrapHTML(
        title: String,
        bodyHTML: String,
        metadata: [String: String] = [:],
        appearance: MarkdownAppearance,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular,
        isTransparent: Bool = false
    ) -> MarkdownRenderResult {
        let escapedTitle = HTMLSanitizer.escape(title)
        return MarkdownRenderResult(
            title: title,
            html: documentHTML(title: escapedTitle, body: bodyHTML, appearance: appearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: isTransparent),
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
        spacing: PreviewSpacing,
        isTransparent: Bool
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
        <html data-appearance="\(appearance.rawValue)">
        <head>
          <meta charset="utf-8">
          <script>
            // Override getComputedStyle to trick Mermaid's theme detection when body background is transparent
            (function() {
              const originalGetComputedStyle = window.getComputedStyle;
              window.getComputedStyle = function(element, pseudoElt) {
                const style = originalGetComputedStyle(element, pseudoElt);
                return new Proxy(style, {
                  get(target, prop) {
                    if (prop === 'backgroundColor') {
                      const val = target[prop];
                      if (val === 'rgba(0, 0, 0, 0)' || val === 'transparent') {
                        const appearance = document.documentElement.getAttribute('data-appearance') || 'light';
                        let isDark = appearance === 'dark';
                        if (appearance === 'system') {
                          isDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
                        }
                        return isDark ? 'rgb(30, 30, 30)' : 'rgb(255, 255, 255)';
                      }
                    }
                    const value = target[prop];
                    if (typeof value === 'function') {
                      return value.bind(target);
                    }
                    return value;
                  }
                });
              };
            })();
          </script>
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
        \(PeekMarkTheme.css(for: appearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: isTransparent))
          
          /* Customized math and code layouts */
          .katex, .katex-display {
            color: var(--text) !important;
          }
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
            // Auto-assign slugified IDs to headings for anchor links
            document.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(function(heading) {
                if (!heading.id) {
                    var text = heading.textContent || "";
                    var slug = text.toLowerCase()
                        .trim()
                        .replace(/[^\\w\\s-]/g, '')
                        .replace(/[\\s_-]+/g, '-')
                        .replace(/^-+|-+$/g, '');
                    heading.id = slug;
                }
            });

            // Mark task list items for styling
            document.querySelectorAll('li input[type="checkbox"]').forEach(function(input) {
                var li = input.closest('li');
                if (li) {
                    li.classList.add('task-list-item');
                    var p = input.closest('p');
                    if (p) {
                        p.style.display = 'inline-flex';
                        p.style.alignItems = 'flex-start';
                        p.style.margin = '0';
                    }
                }
            });

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

            // Add Word Wrap and Copy buttons to all pre blocks (except mermaid blocks)
            document.querySelectorAll('pre').forEach(function(pre) {
                if (pre.querySelector('code.language-mermaid') || pre.classList.contains('mermaid')) {
                    return;
                }
                pre.style.position = 'relative';

                var actionsDiv = document.createElement('div');
                actionsDiv.className = 'code-actions';

                // Wrap Button
                var wrapBtn = document.createElement('button');
                wrapBtn.className = 'code-action-btn';
                wrapBtn.type = 'button';
                wrapBtn.title = 'Toggle Word Wrap';
                wrapBtn.innerHTML = '<svg viewBox="0 0 24 24"><path d="M3 5h18v2H3zm0 4h12c1.7 0 3 1.3 3 3s-1.3 3-3 3H9v-2h6c.6 0 1-.4 1-1s-.4-1-1-1H3zm0 8h18v2H3z"/></svg>';
                wrapBtn.addEventListener('click', function() {
                    pre.classList.toggle('word-wrap');
                });
                actionsDiv.appendChild(wrapBtn);

                // Copy Button
                var copyBtn = document.createElement('button');
                copyBtn.className = 'code-action-btn';
                copyBtn.type = 'button';
                copyBtn.title = 'Copy Code';
                copyBtn.innerHTML = '<svg viewBox="0 0 24 24"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>';
                copyBtn.addEventListener('click', function() {
                    var codeText = pre.querySelector('code') ? pre.querySelector('code').textContent : pre.textContent;
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.copyCode) {
                        window.webkit.messageHandlers.copyCode.postMessage(codeText);
                    }
                    
                    var originalHTML = copyBtn.innerHTML;
                    copyBtn.innerHTML = '<svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>';
                    copyBtn.style.color = '#30d158';
                    setTimeout(function() {
                        copyBtn.innerHTML = originalHTML;
                        copyBtn.style.color = '';
                    }, 2000);
                });
                actionsDiv.appendChild(copyBtn);

                pre.appendChild(actionsDiv);
            });
          </script>          <!-- Load Mermaid ESM -->
          <script type="module">
            import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';

            var appearance = document.documentElement.getAttribute('data-appearance') || 'light';
            var isDark = appearance === 'dark';
            if (appearance === 'system') {
              isDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
            }
            mermaid.initialize({
              startOnLoad: true,
              theme: isDark ? 'dark' : 'default',
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
}
