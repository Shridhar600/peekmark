import Foundation

enum HTMLSanitizer {
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
        output = removeTags(["script", "iframe", "object", "embed", "style", "link", "meta", "base"], from: output)
        output = removeAttributes(matching: #"(?i)\s+on[a-z0-9_-]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)"#, from: output)
        output = removeAttributes(matching: #"(?i)\s+(href|src)\s*=\s*(['"])\s*javascript:[^'"]*\2"#, from: output)
        output = removeAttributes(matching: #"(?i)\s+(href|src)\s*=\s*javascript:[^\s>]*"#, from: output)
        output = removeAttributes(matching: #"(?i)\s+(href|src|srcset|poster|background|xlink:href)\s*=\s*(['"])\s*data:[^'"]*\2"#, from: output)
        output = removeAttributes(matching: #"(?i)\s+(href|src|srcset|poster|background|xlink:href)\s*=\s*data:[^\s>]*"#, from: output)
        output = removeAttributes(matching: #"(?i)\s+(href|src|srcset|poster|background|xlink:href)\s*=\s*(['"])\s*(https?:|//|file:)[^'"]*\2"#, from: output)
        output = removeAttributes(matching: #"(?i)\s+(href|src|srcset|poster|background|xlink:href)\s*=\s*(https?:|//|file:)[^\s>]*"#, from: output)
        output = removeAttributes(matching: #"(?i)\s+style\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)"#, from: output)
        return output
    }

    private static func removeTags(_ tags: [String], from html: String) -> String {
        tags.reduce(html) { partial, tag in
            let withoutPairedTags = replace(
                pattern: #"(?is)<\s*\#(tag)\b[^>]*>.*?<\s*/\s*\#(tag)\s*>"#,
                in: partial,
                with: ""
            )
            return replace(
                pattern: #"(?is)<\s*\#(tag)\b[^>]*\/?\s*>"#,
                in: withoutPairedTags,
                with: ""
            )
        }
    }

    private static func removeAttributes(matching pattern: String, from html: String) -> String {
        replace(pattern: pattern, in: html, with: "")
    }

    private static func replace(pattern: String, in value: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }
}
