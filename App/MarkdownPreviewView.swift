import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let html: String
    var searchText: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html || context.coordinator.lastSearchText != searchText else {
            return
        }
        context.coordinator.lastHTML = html
        context.coordinator.lastSearchText = searchText
        context.coordinator.pendingScrollOrigin = webView.descendantScrollView?.contentView.bounds.origin
        context.coordinator.allowNextMainFrameLoad = true
        webView.loadHTMLString(html, baseURL: nil)

        if !searchText.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                context.coordinator.highlightSearch(in: webView, text: self.searchText)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML = ""
        var lastSearchText = ""
        var allowNextMainFrameLoad = false
        var pendingScrollOrigin: NSPoint?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
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
