import Foundation

enum HTMLSanitizer {
    private static let tagTags = "script|iframe|object|embed|style|link|meta|base"
    private static let pairedTagsRegex = try! NSRegularExpression(
        pattern: "(?is)<\\s*(\(tagTags))\\b[^>]*>.*?<\\s*/\\s*\\1\\s*>",
        options: []
    )
    private static let singleTagsRegex = try! NSRegularExpression(
        pattern: "(?is)<\\s*(\(tagTags))\\b[^>]*\\/?\\s*>",
        options: []
    )
    private static let eventHandlersRegex = try! NSRegularExpression(
        pattern: #"(?i)\s+on[a-z0-9_-]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)"#,
        options: []
    )
    private static let jsURLQuotedRegex = try! NSRegularExpression(
        pattern: #"(?i)\s+(href|src)\s*=\s*(['"])\s*javascript:[^'"]*\2"#,
        options: []
    )
    private static let jsURLUnquotedRegex = try! NSRegularExpression(
        pattern: #"(?i)\s+(href|src)\s*=\s*javascript:[^\s>]*"#,
        options: []
    )
    private static let styleAttrRegex = try! NSRegularExpression(
        pattern: #"(?i)\s+style\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)"#,
        options: []
    )

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
        output = replace(regex: pairedTagsRegex, in: output, with: "")
        output = replace(regex: singleTagsRegex, in: output, with: "")
        output = replace(regex: eventHandlersRegex, in: output, with: "")
        output = replace(regex: jsURLQuotedRegex, in: output, with: "")
        output = replace(regex: jsURLUnquotedRegex, in: output, with: "")
        output = replace(regex: styleAttrRegex, in: output, with: "")
        return output
    }

    private static func replace(regex: NSRegularExpression, in value: String, with replacement: String) -> String {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }
}
