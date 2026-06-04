import Foundation

enum HTMLSanitizer {
    // `video|audio|source|track|picture` are added so the URL strings inside
    // (e.g. `<source srcset="https://tracker/x.png">`, `<video src="…">`) are
    // stripped from the DOM and do not leak via the `srcset` attribute — CSP
    // blocks the fetch, but the URL string itself would otherwise survive.
    private static let tagTags = "script|iframe|object|embed|style|link|meta|base|video|audio|source|track|picture"
    private static let pairedTagsRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: "(?is)<\\s*(\(tagTags))\\b[^>]*>(?>[^<]|<(?!/\\s*\\1\\s*>))*<\\s*/\\s*\\1\\s*>",
            options: []
        )
    }()
    private static let singleTagsRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: "(?is)<\\s*(\(tagTags))\\b[^>]*\\/?\\s*>",
            options: []
        )
    }()
    private static let eventHandlersRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)\s+on[a-z0-9_-]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)"#,
            options: []
        )
    }()
    private static let jsURLQuotedRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)\s+(href|src)\s*=\s*(['"])\s*javascript:[^'"]*\2"#,
            options: []
        )
    }()
    private static let jsURLUnquotedRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)\s+(href|src)\s*=\s*javascript:[^\s>]*"#,
            options: []
        )
    }()
    private static let styleAttrRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)\s+style\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)"#,
            options: []
        )
    }()
    private static let fileURLQuotedRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)\s+href\s*=\s*(['"])file://[^'"]*\1"#,
            options: []
        )
    }()
    private static let fileURLUnquotedRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)\s+href\s*=\s*file://[^\s>]*"#,
            options: []
        )
    }()
    private static let remoteHrefQuotedRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)\s+href\s*=\s*(['"])https?://[^'"]*\1"#,
            options: []
        )
    }()
    private static let remoteHrefUnquotedRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)\s+href\s*=\s*https?://[^\s>]*"#,
            options: []
        )
    }()
    private static let remoteImgSrcRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)<img\b[^>]*?\s+src\s*=\s*(['"])https?://[^'"]*\1[^>]*/?\s*>"#,
            options: []
        )
    }()
    // SVG image data URIs are stripped because raw SVG can host inline scripts
    // (`<script>`, `onload=`, `javascript:` URIs) and would execute inside the
    // WKWebView's renderer subprocess even with our CSP, since `data:` is in
    // `img-src`. Restricting to actually rendered raster image data URIs only
    // avoids that attack surface.
    private static let svgDataSrcRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)<img\b[^>]*?\s+src\s*=\s*(['"])data:image/svg[^'"]*\1[^>]*/?\s*>"#,
            options: []
        )
    }()
    // Local relative image references are stripped because PeekMark runs inside
    // the macOS App Sandbox and only has read access to the file the user
    // explicitly opened. A `<img src="local.png">` next to the Markdown file
    // would resolve to a sibling the sandbox blocks, and the page is loaded
    // with `baseURL: nil` so the WKWebView has no way to fetch it either.
    // Rather than leave a broken-image icon, we strip the whole `<img>` tag.
    // Local image rendering may be added in a future release if a sandbox-
    // safe mechanism (e.g. `loadFileURL` with scoped read access) is adopted.
    //
    // This regex runs AFTER the remote/http and SVG-data-URI strips above, so
    // the only remaining `<img>` tags are raster `data:` URIs (which we keep
    // — they're self-contained, the sandbox has no role) and local-relative
    // paths (which we strip via the negative lookahead).
    private static let localImgTagRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?is)<img\b[^>]*?\s+src\s*=\s*(?!\s*(?:"|')?data:image/(?:png|jpe?g|gif|webp);)[^>]*>"#,
            options: []
        )
    }()
    // Catches `<img>` / `<img alt="x">` (no `src` attribute at all). WKWebView
    // would render these as a broken-image icon. The negative lookahead allows
    // any whitespace before `=`, so `<img src = "…">` is NOT matched here and
    // is left to `localImgTagRegex` (which decides keep-vs-strip based on the
    // value).
    private static let noSrcImgTagRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?is)<img\b(?![^>]*\bsrc\s*=)[^>]*>"#,
            options: []
        )
    }()

    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    // Strips remote resources from generated HTML before it is handed to the
    // WKWebView renderer. This is intentional: opening a Markdown document must
    // not leak the fact that the document was opened, the user's IP address, or
    // local timing information to third-party hosts. The page CSP
    // (`img-src 'self' data:`) provides defence in depth, but the canonical
    // stripping happens here so that remote URLs are removed from the markup
    // itself, not just blocked at fetch time.
    static func sanitizeGeneratedHTML(_ html: String) -> String {
        var output = html
        if let regex = pairedTagsRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = singleTagsRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = eventHandlersRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = jsURLQuotedRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = jsURLUnquotedRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = styleAttrRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = fileURLQuotedRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = fileURLUnquotedRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = remoteHrefQuotedRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = remoteHrefUnquotedRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = remoteImgSrcRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = svgDataSrcRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = noSrcImgTagRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        if let regex = localImgTagRegex {
            output = replace(regex: regex, in: output, with: "")
        }
        return output
    }

    private static func replace(regex: NSRegularExpression, in value: String, with replacement: String) -> String {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }
}
