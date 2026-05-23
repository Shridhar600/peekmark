import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let bodyHTML: String
    let html: String
    let appearance: MarkdownAppearance
    let font: PreviewFont
    let fontSize: Double
    let spacing: PreviewSpacing
    var searchText: String = ""
    @Binding var scrollToHeaderIndex: Int?
    let documentTitle: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Enable Javascript to support syntax highlighting, LaTeX, and Mermaid
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = false

        // Register the script message handler for copying code
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "copyCode")
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        
        // Update webview appearance to match selected appearance
        switch appearance {
        case .system:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            webView.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        case .light:
            webView.appearance = NSAppearance(named: .aqua)
        case .dark:
            webView.appearance = NSAppearance(named: .darkAqua)
        }
        
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let resolvedAppearance: MarkdownAppearance
        switch appearance {
        case .system:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            resolvedAppearance = isDark ? .dark : .light
        case .light:
            resolvedAppearance = .light
        case .dark:
            resolvedAppearance = .dark
        }
        
        webView.appearance = NSAppearance(named: resolvedAppearance == .dark ? .darkAqua : .aqua)

        if let headerIndex = scrollToHeaderIndex {
            let script = """
            (function() {
                var headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
                if (headings[\(headerIndex)]) {
                    headings[\(headerIndex)].scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
            })();
            """
            webView.evaluateJavaScript(script) { _, _ in
                DispatchQueue.main.async {
                    self.scrollToHeaderIndex = nil
                }
            }
        }

        let appearanceChanged = context.coordinator.lastResolvedAppearance != resolvedAppearance
        let bodyChanged = context.coordinator.lastBodyHTML != bodyHTML || context.coordinator.lastSearchText != searchText
        
        if bodyChanged {
            context.coordinator.lastBodyHTML = bodyHTML
            context.coordinator.lastHTML = html
            context.coordinator.lastSearchText = searchText
            context.coordinator.lastFont = font
            context.coordinator.lastFontSize = fontSize
            context.coordinator.lastSpacing = spacing
            context.coordinator.lastResolvedAppearance = resolvedAppearance
            
            context.coordinator.pendingScrollOrigin = webView.descendantScrollView?.contentView.bounds.origin
            context.coordinator.allowNextMainFrameLoad = true
            webView.loadHTMLString(html, baseURL: nil)

            if !searchText.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    context.coordinator.highlightSearch(in: webView, text: self.searchText)
                }
            }
        } else {
            var script = ""
            var fontVarsChanged = false
            var appearanceVarsChanged = false
            
            if context.coordinator.lastFontSize != fontSize || context.coordinator.lastFont != font || context.coordinator.lastSpacing != spacing {
                context.coordinator.lastFont = font
                context.coordinator.lastFontSize = fontSize
                context.coordinator.lastSpacing = spacing
                fontVarsChanged = true
            }
            
            if appearanceChanged {
                context.coordinator.lastResolvedAppearance = resolvedAppearance
                appearanceVarsChanged = true
            }
            
            if fontVarsChanged || appearanceVarsChanged {
                let paragraphMargin = String(format: "%.2frem", fontSize * 0.042)
                let headingTopMargin = String(format: "%.2fem", fontSize * 0.07)
                let headingBottomMargin = String(format: "%.2fem", fontSize * 0.02)
                let cssFamily = font.cssFamily.replacingOccurrences(of: "\"", with: "\\\"")
                
                let isDark = resolvedAppearance == .dark
                let bg = "transparent"
                let text = isDark ? "#d2d2d7" : "#1d1d1f"
                let secondaryText = "#86868b"
                let line = isDark ? "#323236" : "#e5e5e7"
                let softLine = isDark ? "#2c2c30" : "#f5f5f7"
                let codeBg = isDark ? "#2c2c30" : "#f5f5f7"
                let quoteBg = isDark ? "#2c2c30" : "#f5f5f7"
                let tableStripe = isDark ? "#1c1c1e" : "#f9f9fb"
                
                script = """
                (function() {
                    var root = document.documentElement;
                """
                
                if fontVarsChanged {
                    script += """
                    root.style.setProperty('--font-size', '\(fontSize)px');
                    root.style.setProperty('--font-family', '\(cssFamily)');
                    root.style.setProperty('--line-height', '\(spacing.lineSpacing)');
                    root.style.setProperty('--paragraph-margin', '\(paragraphMargin)');
                    root.style.setProperty('--heading-margin', '\(headingTopMargin) 0 \(headingBottomMargin)');
                    """
                }
                
                if appearanceVarsChanged {
                    script += """
                    root.setAttribute('data-appearance', '\(resolvedAppearance.rawValue)');
                    root.style.setProperty('--bg', '\(bg)');
                    root.style.setProperty('--text', '\(text)');
                    root.style.setProperty('--secondary-text', '\(secondaryText)');
                    root.style.setProperty('--line', '\(line)');
                    root.style.setProperty('--soft-line', '\(softLine)');
                    root.style.setProperty('--code-bg', '\(codeBg)');
                    root.style.setProperty('--quote-bg', '\(quoteBg)');
                    root.style.setProperty('--table-stripe', '\(tableStripe)');
                    
                    var lightStyle = document.getElementById('hljs-light');
                    var darkStyle = document.getElementById('hljs-dark');
                    if (lightStyle) { lightStyle.disabled = \(isDark ? "true" : "false"); }
                    if (darkStyle) { darkStyle.disabled = \(!isDark ? "true" : "false"); }
                    
                    if (window.mermaid) {
                        window.mermaid.initialize({
                            theme: '\(isDark ? "dark" : "default")',
                            securityLevel: 'strict'
                        });
                        document.querySelectorAll('.mermaid').forEach(function(el) {
                            var src = el.getAttribute('data-mermaid-src');
                            if (src) {
                                el.innerHTML = '';
                                el.textContent = src;
                                el.removeAttribute('data-processed');
                            }
                        });
                        window.mermaid.run();
                    }
                    """
                }
                
                script += """
                })();
                """
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastBodyHTML = ""
        var lastHTML = ""
        var lastSearchText = ""
        var lastFont: PreviewFont?
        var lastFontSize: Double?
        var lastSpacing: PreviewSpacing?
        var lastResolvedAppearance: MarkdownAppearance?
        var allowNextMainFrameLoad = false
        var pendingScrollOrigin: NSPoint?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "copyCode", let codeString = message.body as? String {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(codeString, forType: .string)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                if url.scheme == "about" {
                    decisionHandler(.allow)
                } else if url.fragment != nil && (url.host == nil || url.scheme == "file") {
                    decisionHandler(.allow)
                } else {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                }
                return
            }

            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
            guard allowNextMainFrameLoad, isMainFrame, navigationAction.navigationType == .other else {
                decisionHandler(.cancel)
                return
            }
            allowNextMainFrameLoad = false
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let pendingScrollOrigin else {
                return
            }
            self.pendingScrollOrigin = nil
            guard let scrollView = webView.descendantScrollView else {
                return
            }
            scrollView.contentView.scroll(to: pendingScrollOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        func highlightSearch(in webView: WKWebView, text: String) {
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            let script = """
            (function() {
                var query = '\(escaped)';
                if (!query || query.length < 2) return;

                // Remove existing highlights
                var existing = document.querySelectorAll('.search-highlight');
                existing.forEach(function(el) {
                    var parent = el.parentNode;
                    while (el.firstChild) parent.insertBefore(el.firstChild, el);
                    parent.removeChild(el);
                });

                if (!document.getElementById('search-highlight-style')) {
                    var style = document.createElement('style');
                    style.id = 'search-highlight-style';
                    style.textContent = '.search-highlight { background-color: #ffd60a; color: #000; padding: 0 2px; border-radius: 2px; }';
                    document.head.appendChild(style);
                }

                // Find and highlight matches
                var walker = document.createTreeWalker(
                    document.body,
                    NodeFilter.SHOW_TEXT,
                    null,
                    false
                );
                var nodes = [];
                var node;
                while (node = walker.nextNode()) {
                    var parent = node.parentNode;
                    if (parent && (parent.tagName === 'MARK' || parent.tagName === 'SCRIPT' || parent.tagName === 'STYLE')) continue;
                    if (node.nodeValue.toLowerCase().includes(query.toLowerCase())) {
                        nodes.push(node);
                    }
                }

                if (nodes.length === 0) return;

                nodes.forEach(function(textNode) {
                    var text = textNode.nodeValue;
                    var lower = text.toLowerCase();
                    var queryLower = query.toLowerCase();
                    var frag = document.createDocumentFragment();
                    var last = 0;
                    var idx = lower.indexOf(queryLower);
                    while (idx !== -1) {
                        frag.appendChild(document.createTextNode(text.substring(last, idx)));
                        var mark = document.createElement('mark');
                        mark.className = 'search-highlight';
                        mark.textContent = text.substring(idx, idx + query.length);
                        frag.appendChild(mark);
                        last = idx + query.length;
                        idx = lower.indexOf(queryLower, last);
                    }
                    frag.appendChild(document.createTextNode(text.substring(last)));
                    textNode.parentNode.replaceChild(frag, textNode);
                });

                // Scroll to first match
                var first = document.querySelector('.search-highlight');
                if (first) first.scrollIntoView({ behavior: 'smooth', block: 'center' });
            })();
            """

            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}

private extension NSView {
    var descendantScrollView: NSScrollView? {
        if let scrollView = self as? NSScrollView {
            return scrollView
        }
        for subview in subviews {
            if let scrollView = subview.descendantScrollView {
                return scrollView
            }
        }
        return nil
    }
}
