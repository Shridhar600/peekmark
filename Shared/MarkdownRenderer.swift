import Foundation
import Markdown

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
        fontSize: Double = 12,
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
        fontSize: Double = 12,
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
        // `baseURL` is accepted but currently unused for local image embedding
        // — PeekMark is sandboxed and intentionally does not read sibling image
        // files in the first public release. See README "Limitations".
        _ = baseURL
        return renderBodySync(markdown: markdown)
    }

    private static func renderBodySync(markdown: String) -> (bodyHTML: String, headings: [HeadingItem]) {
        let (processedMarkdown, footnotesHTML) = processFootnotes(markdown)
        let document = Document(parsing: processedMarkdown)
        let body = HTMLSanitizer.sanitizeGeneratedHTML(HTMLFormatter.format(document))
        let headings = HeadingExtractor.extract(from: document)
        return (body + footnotesHTML, headings)
    }

    static func renderBodyAsync(markdown: String, baseURL: URL? = nil) async -> (bodyHTML: String, headings: [HeadingItem]) {
        // `baseURL` is accepted but currently unused for local image embedding
        // — PeekMark is sandboxed and intentionally does not read sibling image
        // files in the first public release. See README "Limitations".
        _ = baseURL
        return renderBodySync(markdown: markdown)
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
        fontSize: Double = 12,
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
        return documentHTML(
            title: title,
            body: body,
            appearance: appearance,
            font: font,
            fontSize: fontSize,
            spacing: spacing,
            isTransparent: isTransparent,
            webAssets: WebAssetBundle.load()
        )
    }

    /// Test seam: accepts an explicit `WebAssetBundle?` value so tests can
    /// exercise the asset-present and asset-missing code paths without
    /// depending on `WebAssetBundle.load()` static state. App/Extension
    /// code should use the private overload (which calls `load()`) instead.
    internal static func documentHTML(
        title: String,
        body: String,
        appearance: MarkdownAppearance,
        font: PreviewFont,
        fontSize: Double,
        spacing: PreviewSpacing,
        isTransparent: Bool,
        webAssets: WebAssetBundle?
    ) -> String {
        let isDark = appearance == .dark
        let highlightCSSLink: String
        let highlightScript: String
        let katexCSS: String
        let katexScript: String
        let katexAutoRenderScript: String
        let mermaidScript: String
        let assetErrorBanner: String?

        if let webAssets {
            highlightCSSLink = webAssets.highlightStyles(isDark: isDark)
            highlightScript = webAssets.scriptTag(id: "hljs-script", source: \.highlightJS)
            katexCSS = webAssets.styleTag(id: "katex-style", source: \.katexCSS)
            katexScript = webAssets.scriptTag(id: "katex-script", source: \.katexJS)
            katexAutoRenderScript = webAssets.scriptTag(id: "katex-auto-render-script", source: \.katexAutoRenderJS)
            mermaidScript = webAssets.scriptTag(id: "mermaid-script", source: \.mermaidJS)
            assetErrorBanner = nil
        } else {
            highlightCSSLink = ""
            highlightScript = ""
            katexCSS = ""
            katexScript = ""
            katexAutoRenderScript = ""
            mermaidScript = ""
            assetErrorBanner = """
            <div class="peekmark-asset-error" style="background:#fff4cc;color:#5a4500;border:1px solid #e0c44a;padding:12px 16px;margin:0 0 16px 0;font:14px -apple-system,system-ui,sans-serif;border-radius:6px;">PeekMark failed to load bundled web assets. Code highlighting, math, and diagrams are disabled in this preview.</div>
            """
        }

        return """
        <!doctype html>
        <html data-appearance="\(appearance.rawValue)">
        <head>
          <meta charset="utf-8">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; font-src data:; img-src 'self' data:; connect-src 'none';">
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
        \(assetErrorBanner ?? "")
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
}

private final class WebAssetBundleMarker: NSObject {}

struct WebAssetBundle {
    let highlightLightCSS: String
    let highlightDarkCSS: String
    let highlightJS: String
    let katexCSS: String
    let katexJS: String
    let katexAutoRenderJS: String
    let mermaidJS: String

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
        \(styleTag(id: "hljs-light", css: highlightLightCSS, media: isDark ? "not all" : "all"))
        \(styleTag(id: "hljs-dark", css: highlightDarkCSS, media: isDark ? "all" : "not all"))
        """
    }

    func styleTag(id: String, source: KeyPath<WebAssetBundle, String>) -> String {
        styleTag(id: id, css: self[keyPath: source])
    }

    func scriptTag(id: String, source: KeyPath<WebAssetBundle, String>) -> String {
        #"<script id="\#(id)">\#(Self.escapeScript(self[keyPath: source]))</script>"#
    }

    private func styleTag(id: String, css: String, media: String = "all") -> String {
        #"<style id="\#(id)" media="\#(media)">\#(Self.escapeStyle(css))</style>"#
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
