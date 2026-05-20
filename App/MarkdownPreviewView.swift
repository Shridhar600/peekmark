import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let html: String

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
        guard context.coordinator.lastHTML != html else {
            return
        }
        context.coordinator.lastHTML = html
        context.coordinator.pendingScrollOrigin = webView.descendantScrollView?.contentView.bounds.origin
        context.coordinator.allowNextMainFrameLoad = true
        webView.loadHTMLString(html, baseURL: nil)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML = ""
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
