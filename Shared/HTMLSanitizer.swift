import Foundation

enum HTMLSanitizer {
    private static let tagTags = "script|iframe|object|embed|style|link|meta|base"
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
    private static let svgDataSrcRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?i)<img\b[^>]*?\s+src\s*=\s*(['"])data:image/svg[^'"]*\1[^>]*/?\s*>"#,
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
        return output
    }

    private static func replace(regex: NSRegularExpression, in value: String, with replacement: String) -> String {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }
}
