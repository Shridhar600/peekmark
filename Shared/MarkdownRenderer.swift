import Foundation
import Markdown
import UniformTypeIdentifiers

struct MarkdownRenderResult {
    let title: String
    let html: String
    let bodyHTML: String
    let metadata: [String: String]
    let headings: [HeadingItem]
}

enum MarkdownRenderer {
    private static let footnoteDefinitionRegex = try! NSRegularExpression(pattern: "^\\[\\^([^\\]]+)\\]:\\s*(.*)$", options: [])
    private static let footnoteReferenceRegex = try! NSRegularExpression(pattern: "\\[\\^([^\\]]+)\\]", options: [])

    static func render(
        markdown: String,
        title: String,
        baseURL: URL? = nil,
        appearance: MarkdownAppearance = .light,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular,
        isTransparent: Bool = false
    ) async -> MarkdownRenderResult {
        let (metadata, content) = parseFrontMatter(markdown)

        let (bodyHTML, headings) = await renderBodyAsync(markdown: content, baseURL: baseURL)

        return wrapHTML(title: title, bodyHTML: bodyHTML, metadata: metadata, headings: headings, appearance: appearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: isTransparent)
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
        return wrapHTML(title: title, bodyHTML: body, metadata: [:], headings: [], appearance: appearance, font: font, fontSize: fontSize, spacing: spacing, isTransparent: isTransparent)
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

    static func renderBody(markdown: String, baseURL: URL? = nil) -> (bodyHTML: String, headings: [HeadingItem]) {
        let (processedMarkdown, footnotesHTML) = processFootnotes(markdown)
        let document = Document(parsing: processedMarkdown)
        let body = HTMLSanitizer.sanitizeGeneratedHTML(HTMLFormatter.format(document))
        let bodyWithImages = embedLocalImages(in: body, baseURL: baseURL)
        let headings = HeadingExtractor.extract(from: document)
        return (bodyWithImages + footnotesHTML, headings)
    }

    static func renderBodyAsync(markdown: String, baseURL: URL? = nil) async -> (bodyHTML: String, headings: [HeadingItem]) {
        let (processedMarkdown, footnotesHTML) = processFootnotes(markdown)
        let document = Document(parsing: processedMarkdown)
        let body = HTMLSanitizer.sanitizeGeneratedHTML(HTMLFormatter.format(document))

        let bodyWithImages: String
        if let baseURL = baseURL {
            bodyWithImages = await ImageEmbeddingActor.shared.rewrite(html: body, baseDirectory: baseURL)
        } else {
            bodyWithImages = body
        }

        let headings = HeadingExtractor.extract(from: document)
        return (bodyWithImages + footnotesHTML, headings)
    }

    private static func processFootnotes(_ markdown: String) -> (processedMarkdown: String, footnotesHTML: String) {
        var processed = markdown
        var footnotes: [(label: String, content: String)] = []
        
        let lines = markdown.components(separatedBy: .newlines)
        var bodyLines: [String] = []
        var currentLabel: String? = nil
        var currentContent = ""
        
        for line in lines {
            if let match = footnoteDefinitionRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                if let label = currentLabel {
                    footnotes.append((label, currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                
                let labelRange = match.range(at: 1)
                let contentRange = match.range(at: 2)
                let matchedLabel = (line as NSString).substring(with: labelRange)
                let content = (line as NSString).substring(with: contentRange)
                
                currentLabel = matchedLabel
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
        
        let refRegex = footnoteReferenceRegex
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
        
        guard !footnotes.isEmpty else {
            return (processed, "")
        }
        
        var footnotesHTML = "<div class=\"footnotes\">\n<hr>\n<ol>\n"
        for footnote in footnotes {
            let contentDoc = Document(parsing: footnote.content)
            var contentHTML = HTMLFormatter.format(contentDoc)
            contentHTML = HTMLSanitizer.sanitizeGeneratedHTML(contentHTML)

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
        headings: [HeadingItem] = [],
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
            metadata: metadata,
            headings: headings
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
        let isDark = appearance == .dark
        let webAssets = WebAssetBundle.load()
        let highlightCSSLink = webAssets?.highlightStyles(isDark: isDark) ?? WebAssetBundle.cdnHighlightStyles(isDark: isDark)
        let highlightScript = webAssets?.scriptTag(id: "hljs-script", source: \.highlightJS) ?? WebAssetBundle.cdnHighlightScript
        let katexCSS = webAssets?.styleTag(id: "katex-style", source: \.katexCSS) ?? WebAssetBundle.cdnKatexStyle
        let katexScript = webAssets?.scriptTag(id: "katex-script", source: \.katexJS) ?? WebAssetBundle.cdnKatexScript
        let katexAutoRenderScript = webAssets?.scriptTag(id: "katex-auto-render-script", source: \.katexAutoRenderJS) ?? WebAssetBundle.cdnKatexAutoRenderScript
        let mermaidScript = webAssets?.scriptTag(id: "mermaid-script", source: \.mermaidJS) ?? WebAssetBundle.cdnMermaidScript

        return """
        <!doctype html>
        <html data-appearance="\(appearance.rawValue)">
        <head>
          <meta charset="utf-8">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; font-src data: https://cdn.jsdelivr.net; img-src 'self' data:; connect-src 'self';">
          <script>
            // Mock matchMedia to match resolved appearance
            (function() {
              const originalMatchMedia = window.matchMedia;
              window.matchMedia = function(query) {
                if (query.includes('prefers-color-scheme')) {
                  const appearance = document.documentElement.getAttribute('data-appearance') || 'light';
                  let isDark = appearance === 'dark';
                  if (appearance === 'system') {
                    isDark = originalMatchMedia && originalMatchMedia('(prefers-color-scheme: dark)').matches;
                  }
                  const matches = query.includes('dark') ? isDark : !isDark;
                  return {
                    matches: matches,
                    media: query,
                    onchange: null,
                    addListener: function() {},
                    removeListener: function() {},
                    addEventListener: function() {},
                    removeEventListener: function() {},
                    dispatchEvent: function() { return false; }
                  };
                }
                return originalMatchMedia ? originalMatchMedia(query) : { matches: false, media: query };
              };
            })();

            // Override getComputedStyle specifically for document.body to trick Mermaid's theme detection when body is transparent
            (function() {
              const originalGetComputedStyle = window.getComputedStyle;
              window.getComputedStyle = function(element, pseudoElt) {
                const style = originalGetComputedStyle(element, pseudoElt);
                if (element === document.body || element === document.documentElement) {
                  return new Proxy(style, {
                    get(target, prop) {
                      if (prop === 'backgroundColor') {
                        const val = target[prop];
                        if (val === 'rgba(0, 0, 0, 0)' || val === 'transparent') {
                          const appearance = document.documentElement.getAttribute('data-appearance') || 'light';
                          return appearance === 'dark' ? 'rgb(30, 30, 30)' : 'rgb(255, 255, 255)';
                        }
                      }
                      const value = target[prop];
                      return typeof value === 'function' ? value.bind(target) : value;
                    }
                  });
                }
                return style;
              };
            })();
          </script>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title)</title>
          
          <!-- Highlight.js for Syntax Highlighting -->
          \(highlightCSSLink)
          \(highlightScript)
          
          <!-- KaTeX for LaTeX Render -->
          \(katexCSS)
          \(katexScript)
          \(katexAutoRenderScript)

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
                div.setAttribute('data-mermaid-src', codeBlock.textContent);
                div.textContent = codeBlock.textContent;
                pre.parentNode.replaceChild(div, pre);
            });

            // Run optional vendor enhancements only when their assets loaded.
            if (window.hljs && typeof window.hljs.highlightAll === 'function') {
                window.hljs.highlightAll();
            }

            if (typeof window.renderMathInElement === 'function') {
                window.renderMathInElement(document.body, {
                    delimiters: [
                        {left: '$$', right: '$$', display: true},
                        {left: '$', right: '$', display: false},
                        {left: '\\\\(', right: '\\\\)', display: false},
                        {left: '\\\\[', right: '\\\\]', display: true}
                    ],
                    throwOnError : false
                });
            }

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
          </script>
          <!-- Load Mermaid (IIFE version for better CSP compatibility) -->
          \(mermaidScript)
          <script>
            (function() {
              var appearance = document.documentElement.getAttribute('data-appearance') || 'light';
              var isDark = appearance === 'dark';
              if (appearance === 'system') {
                isDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
              }
              if (window.mermaid && typeof window.mermaid.initialize === 'function' && typeof window.mermaid.run === 'function') {
                window.mermaid.initialize({
                  startOnLoad: false,
                  theme: isDark ? 'dark' : 'default',
                  securityLevel: 'strict'
                });
                window.mermaid.run();
              }
            })();
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

    private actor ImageEmbeddingActor {
        static let shared = ImageEmbeddingActor()
        private init() {}

        func rewrite(html: String, baseDirectory: URL) -> String {
            return LocalImageDataURIRewriter.rewrite(html: html, baseDirectory: baseDirectory)
        }
    }
}

private enum LocalImageDataURIRewriter {
    private static let imgSrcRegex = try! NSRegularExpression(
        pattern: #"(<img\b[^>]*?\bsrc=")([^"]*)(")"#,
        options: [.caseInsensitive]
    )

    private static let supportedMimeTypes = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "webp": "image/webp"
    ]

    private static let supportedImageUTTypes: Set<UTType> = [
        .png,
        .jpeg,
        .gif,
        .webP
    ]

    static func rewrite(
        html: String,
        baseDirectory: URL,
        byteLimit: Int = 4 * 1024 * 1024,
        aggregateByteLimit: Int = 12 * 1024 * 1024
    ) -> String {
        let nsHTML = html as NSString
        let regex = imgSrcRegex
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
        guard let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
              let utType = resourceValues.contentType,
              supportedImageUTTypes.contains(utType) else {
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

private final class WebAssetBundleMarker: NSObject {}

private struct WebAssetBundle {
    let highlightLightCSS: String
    let highlightDarkCSS: String
    let highlightJS: String
    let katexCSS: String
    let katexJS: String
    let katexAutoRenderJS: String
    let mermaidJS: String

    static func cdnHighlightStyles(isDark: Bool) -> String {
        """
        <link id="hljs-light" rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/styles/github.min.css" integrity="sha256-Oppd74ucMR5a5Dq96FxjEzGF7tTw2fZ/6ksAqDCM8GY=" crossorigin="anonymous" \(isDark ? "disabled" : "")>
        <link id="hljs-dark" rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/styles/github-dark.min.css" integrity="sha256-nyCNAiECsdDHrr/s2OQsp5l9XeY2ZJ0rMepjCT2AkBk=" crossorigin="anonymous" \(!isDark ? "disabled" : "")>
        """
    }
    static let cdnHighlightScript = #"<script id="hljs-script" src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/highlight.min.js" integrity="sha256-xKOZ3W9Ii8l6NUbjR2dHs+cUyZxXuUcxVMb7jSWbk4E=" crossorigin="anonymous"></script>"#
    static let cdnKatexStyle = #"<link id="katex-style" rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/katex.min.css" integrity="sha256-94eJG1UNVUwhSqiQLzmsRt8tvUj97FAKIECl3OHoq1g=" crossorigin="anonymous">"#
    static let cdnKatexScript = #"<script id="katex-script" src="https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/katex.min.js" integrity="sha256-hjgR4rqghJx3vJLSbUT00KSEPCqKtSxGIBfepXMW5Ng=" crossorigin="anonymous"></script>"#
    static let cdnKatexAutoRenderScript = #"<script id="katex-auto-render-script" src="https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/contrib/auto-render.min.js" integrity="sha256-u1PrlTOUUxquNv3VNwZcQkTrhUKQGjzpFGAdkyZ1uKw=" crossorigin="anonymous"></script>"#
    static let cdnMermaidScript = #"<script id="mermaid-script" src="https://cdn.jsdelivr.net/npm/mermaid@11.15.0/dist/mermaid.min.js" integrity="sha256-cBN+d7snO7LvlyuG6LBADMqL5TyyW/xFkRoYbcmGZd4=" crossorigin="anonymous"></script>"#

    private static let bundledAssets = loadFromCandidateResourceRoots(preferred: Bundle(for: WebAssetBundleMarker.self))

    static func load(bundle: Bundle = .main) -> WebAssetBundle? {
        if bundle.bundleURL != Bundle.main.bundleURL,
           let assets = loadUncached(bundle: bundle) {
            return assets
        }

        return bundledAssets
    }

    private static func loadUncached(bundle: Bundle) -> WebAssetBundle? {
        guard let resourceURL = bundle.resourceURL else {
            return nil
        }
        return loadUncached(resourceRoot: resourceURL)
    }

    private static func loadUncached(resourceRoot: URL) -> WebAssetBundle? {
        guard
            let highlightLightCSS = read("highlight/github.min.css", resourceRoot: resourceRoot),
            let highlightDarkCSS = read("highlight/github-dark.min.css", resourceRoot: resourceRoot),
            let highlightJS = read("highlight/highlight.min.js", resourceRoot: resourceRoot),
            let katexCSS = readKatexCSS(resourceRoot: resourceRoot),
            let katexJS = read("katex/js/katex.min.js", resourceRoot: resourceRoot),
            let katexAutoRenderJS = read("katex/js/auto-render.min.js", resourceRoot: resourceRoot),
            let mermaidJS = read("mermaid/mermaid.min.js", resourceRoot: resourceRoot)
        else {
            return nil
        }

        return WebAssetBundle(
            highlightLightCSS: highlightLightCSS,
            highlightDarkCSS: highlightDarkCSS,
            highlightJS: highlightJS,
            katexCSS: katexCSS,
            katexJS: katexJS,
            katexAutoRenderJS: katexAutoRenderJS,
            mermaidJS: mermaidJS
        )
    }

    private static func loadFromCandidateResourceRoots(preferred: Bundle) -> WebAssetBundle? {
        for resourceRoot in candidateResourceRoots(preferred: preferred) {
            if let assets = loadUncached(resourceRoot: resourceRoot) {
                return assets
            }
        }
        return nil
    }

    private static func candidateResourceRoots(preferred: Bundle) -> [URL] {
        var candidates: [URL] = []
        var seen = Set<URL>()

        func append(_ url: URL?) {
            guard let url else {
                return
            }
            let standardized = url.standardizedFileURL
            guard seen.insert(standardized).inserted else {
                return
            }
            candidates.append(standardized)
        }

        for bundle in [preferred, Bundle.main] {
            append(bundle.resourceURL)
            append(bundle.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true))
        }

        return candidates
    }

    func highlightStyles(isDark: Bool) -> String {
        """
        \(styleTag(id: "hljs-light", css: highlightLightCSS, disabled: isDark))
        \(styleTag(id: "hljs-dark", css: highlightDarkCSS, disabled: !isDark))
        """
    }

    func styleTag(id: String, source: KeyPath<WebAssetBundle, String>) -> String {
        styleTag(id: id, css: self[keyPath: source])
    }

    func scriptTag(id: String, source: KeyPath<WebAssetBundle, String>) -> String {
        #"<script id="\#(id)">\#(Self.escapeScript(self[keyPath: source]))</script>"#
    }

    private func styleTag(id: String, css: String, disabled: Bool = false) -> String {
        #"<style id="\#(id)"\#(disabled ? " disabled" : "")>\#(Self.escapeStyle(css))</style>"#
    }

    private static func read(_ relativePath: String, resourceRoot: URL) -> String? {
        let url = resourceRoot
            .appendingPathComponent("WebAssets", isDirectory: true)
            .appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func readData(_ relativePath: String, resourceRoot: URL) -> Data? {
        let url = resourceRoot
            .appendingPathComponent("WebAssets", isDirectory: true)
            .appendingPathComponent(relativePath)
        return try? Data(contentsOf: url)
    }

    private static func readKatexCSS(resourceRoot: URL) -> String? {
        guard var css = read("katex/css/katex.min.css", resourceRoot: resourceRoot) else {
            return nil
        }

        for fontPath in Set(css.matches(of: /fonts\/[^)]*\.woff2/).map { String($0.output) }) {
            guard let fontData = readData("katex/\(fontPath)", resourceRoot: resourceRoot) else {
                return nil
            }
            let dataURL = "data:font/woff2;base64,\(fontData.base64EncodedString())"
            css = css.replacingOccurrences(of: "url(\(fontPath))", with: "url(\(dataURL))")
        }
        return css
    }

    private static func escapeScript(_ script: String) -> String {
        script.replacingOccurrences(of: "</script", with: "<\\/script", options: [.caseInsensitive])
    }

    private static func escapeStyle(_ style: String) -> String {
        style.replacingOccurrences(of: "</style", with: "<\\/style", options: [.caseInsensitive])
    }
}
