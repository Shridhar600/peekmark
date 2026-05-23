import Foundation

#if canImport(AppKit)
import AppKit
#endif

enum MarkdownAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    #if canImport(AppKit)
    var resolved: MarkdownAppearance {
        switch self {
        case .system:
            let isDark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    #endif
}

enum PreviewFont: String, CaseIterable, Identifiable {
    case system
    case serif
    case mono
    case rounded
    case avenir
    case palatino
    case optima
    case courier

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System Sans"
        case .serif: return "Serif (Georgia)"
        case .mono: return "Monospace"
        case .rounded: return "Rounded"
        case .avenir: return "Avenir Next"
        case .palatino: return "Palatino"
        case .optima: return "Optima"
        case .courier: return "Courier"
        }
    }

    var cssFamily: String {
        switch self {
        case .system:
            return "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Helvetica, Arial, sans-serif"
        case .serif:
            return "Georgia, \"Times New Roman\", serif"
        case .mono:
            return "\"SF Mono\", Menlo, Monaco, Consolas, monospace"
        case .rounded:
            return "system-ui, ui-rounded, -apple-system, BlinkMacSystemFont, sans-serif"
        case .avenir:
            return "\"Avenir Next\", Avenir, sans-serif"
        case .palatino:
            return "Palatino, \"Palatino Linotype\", \"Palatino LT STD\", \"Book Antiqua\", Georgia, serif"
        case .optima:
            return "Optima, Segoe, sans-serif"
        case .courier:
            return "\"Courier New\", Courier, monospace"
        }
    }
}

enum PreviewSpacing: String, CaseIterable, Identifiable {
    case compact
    case regular
    case loose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .regular: return "Regular"
        case .loose: return "Loose"
        }
    }

    var lineSpacing: Double {
        switch self {
        case .compact: return 1.3
        case .regular: return 1.45
        case .loose: return 1.65
        }
    }
}

enum PeekMarkTheme {
    private static nonisolated(unsafe) var cssCache: [CacheKey: String] = [:]

    private struct CacheKey: Hashable {
        let appearance: MarkdownAppearance
        let font: PreviewFont
        let fontSize: Double
        let spacing: PreviewSpacing
    }

    static func css(
        for appearance: MarkdownAppearance = .system,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular,
        isTransparent: Bool = false
    ) -> String {
        let cacheKey = CacheKey(appearance: appearance, font: font, fontSize: fontSize, spacing: spacing)
        if let cached = cssCache[cacheKey] {
            return cached
        }
        let generatedCSS: String
        switch appearance {
        case .system:
            generatedCSS = css(
                colorScheme: "light dark",
                background: isTransparent ? "transparent" : "#ffffff",
                text: "#1d1d1f",
                secondaryText: "#86868b",
                line: "#e5e5e7",
                softLine: "#f5f5f7",
                codeBackground: "#f5f5f7",
                quoteBackground: "#f5f5f7",
                tableStripe: "#f9f9fb",
                font: font,
                fontSize: fontSize,
                spacing: spacing,
                adaptiveDarkCSS: adaptiveDarkCSS(isTransparent: isTransparent)
            )
        case .light:
            generatedCSS = css(
                colorScheme: "light",
                background: isTransparent ? "transparent" : "#ffffff",
                text: "#1d1d1f",
                secondaryText: "#86868b",
                line: "#e5e5e7",
                softLine: "#f5f5f7",
                codeBackground: "#f5f5f7",
                quoteBackground: "#f5f5f7",
                tableStripe: "#f9f9fb",
                font: font,
                fontSize: fontSize,
                spacing: spacing,
                adaptiveDarkCSS: ""
            )
        case .dark:
            generatedCSS = css(
                colorScheme: "dark",
                background: isTransparent ? "transparent" : "#1e1e1e",
                text: "#d2d2d7",
                secondaryText: "#86868b",
                line: "#323236",
                softLine: "#2c2c30",
                codeBackground: "#2c2c30",
                quoteBackground: "#2c2c30",
                tableStripe: "#1c1c1e",
                font: font,
                fontSize: fontSize,
                spacing: spacing,
                adaptiveDarkCSS: ""
            )
        }
        cssCache[cacheKey] = generatedCSS
        return generatedCSS
    }

    private static func adaptiveDarkCSS(isTransparent: Bool) -> String {
        """

    @media (prefers-color-scheme: dark) {
      :root {
        --bg: \(isTransparent ? "transparent" : "#1e1e1e");
        --text: #d2d2d7;
        --secondary-text: #86868b;
        --line: #323236;
        --soft-line: #2c2c30;
        --code-bg: #2c2c30;
        --quote-bg: #2c2c30;
        --table-stripe: #1c1c1e;
        --link: #5eb5ff;
      }
    }
    """
    }

    private static func css(
        colorScheme: String,
        background: String,
        text: String,
        secondaryText: String,
        line: String,
        softLine: String,
        codeBackground: String,
        quoteBackground: String,
        tableStripe: String,
        font: PreviewFont,
        fontSize: Double,
        spacing: PreviewSpacing,
        adaptiveDarkCSS: String
    ) -> String {
        let paragraphMargin = String(format: "%.2frem", fontSize * 0.042)
        let headingTopMargin = String(format: "%.2fem", fontSize * 0.07)
        let headingBottomMargin = String(format: "%.2fem", fontSize * 0.02)

        return """
    :root {
      color-scheme: \(colorScheme);
      --bg: \(background);
      --text: \(text);
      --secondary-text: \(secondaryText);
      --line: \(line);
      --soft-line: \(softLine);
      --code-bg: \(codeBackground);
      --quote-bg: \(quoteBackground);
      --table-stripe: \(tableStripe);
      --font-family: \(font.cssFamily);
      --font-size: \(fontSize)px;
      --line-height: \(spacing.lineSpacing);
      --paragraph-margin: \(paragraphMargin);
      --heading-margin: \(headingTopMargin) 0 \(headingBottomMargin);
      --padding-vertical: max(16px, calc(var(--font-size) * 1.4));
      --padding-horizontal: max(24px, calc(var(--font-size) * 1.8));
      --max-width: calc(var(--font-size) * 48);
      --link: \(colorScheme.contains("light") ? "#0055cc" : "#5eb5ff");
    }

    * { box-sizing: border-box; }

    html, body {
      max-width: 100%;
      overflow-x: hidden;
    }

    html {
      background: var(--bg);
      color: var(--text);
      font-family: var(--font-family);
      font-size: var(--font-size);
      line-height: var(--line-height);
    }

    body {
      margin: 0;
      padding: calc(var(--padding-vertical) + 36px) var(--padding-horizontal) var(--padding-vertical) var(--padding-horizontal);
      background: var(--bg);
    }

    main {
      max-width: var(--max-width);
      margin: 0 auto;
    }

    h1, h2, h3, h4, h5, h6 {
      line-height: 1.25;
      letter-spacing: -0.01em;
      margin: var(--heading-margin);
      color: var(--text);
      font-weight: 600;
    }

    h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
    h1 { font-size: 2.1rem; }
    h2 { font-size: 1.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid var(--line); }
    h3 { font-size: 1.25rem; }

    p, ul, ol, blockquote, table, pre { margin: 0 0 var(--paragraph-margin); }
    a { color: var(--link); text-decoration-thickness: 0.08em; text-underline-offset: 0.18em; }
    img { max-width: 100%; height: auto; }

    blockquote {
      padding: 0.6rem 0.9rem;
      border-left: 3px solid var(--line);
      background: var(--quote-bg);
      color: var(--secondary-text);
    }

    code {
      padding: 0.12rem 0.28rem;
      border-radius: 3px;
      background: var(--code-bg);
      font: 0.9em/1.4 "SF Mono", Menlo, monospace;
    }

    pre {
      overflow-x: auto;
      padding: 0.8rem 1rem;
      border: 1px solid var(--soft-line);
      border-radius: 4px;
      background: var(--code-bg);
      color: var(--text);
      position: relative;
    }

    pre code {
      padding: 0;
      background: transparent;
      color: inherit;
      font-size: 0.88rem;
    }

    table {
      display: block;
      width: 100%;
      overflow-x: auto;
      border-collapse: collapse;
      font-size: 0.9rem;
    }

    th, td {
      padding: 0.45rem 0.6rem;
      border: 1px solid var(--line);
      text-align: left;
      vertical-align: top;
    }

    tr:nth-child(even) td { background: var(--table-stripe); }
    hr { border: 0; border-top: 1px solid var(--line); margin: 1.4rem 0; }
    
    .front-matter {
      background: var(--code-bg);
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 12px 16px;
      margin-bottom: 24px;
      font-size: 0.88rem;
    }
    .front-matter-title {
      font-weight: 600;
      color: var(--secondary-text);
      text-transform: uppercase;
      font-size: 0.72rem;
      letter-spacing: 0.05em;
      margin-bottom: 8px;
      border-bottom: 1px solid var(--soft-line);
      padding-bottom: 4px;
    }
    .front-matter-table {
      width: 100%;
      border-collapse: collapse;
      margin: 0 !important;
    }
    .front-matter-table td {
      padding: 4px 0 !important;
      border: none !important;
      background: transparent !important;
    }
    .front-matter-key {
      font-weight: 500;
      color: var(--secondary-text);
      width: 120px;
    }
    .front-matter-value {
      color: var(--text);
    }

    /* GFM Task List Styling */
    li.task-list-item, li:has(input[type="checkbox"]) {
      list-style-type: none !important;
      display: flex !important;
      align-items: flex-start !important;
      margin-left: -1.3em;
    }
    li.task-list-item input[type="checkbox"], li:has(input[type="checkbox"]) input[type="checkbox"] {
      margin-top: 0.25em !important;
      margin-right: 6px !important;
      flex-shrink: 0 !important;
      transform: scale(1.15) !important;
      cursor: default;
    }
    li.task-list-item p, li:has(input[type="checkbox"]) p {
      margin: 0 !important;
      display: inline-flex !important;
      align-items: flex-start !important;
    }

    /* Code block action buttons styling */
    .code-actions {
      position: absolute;
      top: 6px;
      right: 6px;
      display: flex;
      gap: 6px;
      opacity: 0;
      transition: opacity 0.2s ease-in-out;
      z-index: 10;
    }
    pre:hover .code-actions {
      opacity: 1;
    }
    .code-action-btn {
      background: rgba(128, 128, 128, 0.08);
      border: 1px solid var(--soft-line);
      border-radius: 4px;
      padding: 4px 6px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--secondary-text);
      transition: all 0.15s ease;
    }
    .code-action-btn:hover {
      background: rgba(128, 128, 128, 0.18);
      color: var(--text);
      border-color: var(--line);
    }
    .code-action-btn svg {
      width: 12px;
      height: 12px;
      fill: currentColor;
    }
    pre.word-wrap {
      white-space: pre-wrap !important;
      word-break: break-word !important;
    }
    pre.word-wrap code {
      white-space: pre-wrap !important;
      word-break: break-word !important;
    }

    /* Footnotes */
    .footnotes {
      font-size: 0.82rem;
      color: var(--secondary-text);
      margin-top: 2.5rem;
      border-top: 1px solid var(--line);
      padding-top: 1.2rem;
    }
    .footnote-ref a {
      text-decoration: none;
      font-weight: 600;
    }
    .footnote-backref {
      text-decoration: none;
      margin-left: 4px;
      color: var(--secondary-text);
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    }
    .footnote-backref:hover {
      color: var(--text);
    }

    \(adaptiveDarkCSS)

    @media (max-width: 800px) {
      body { padding: calc(var(--padding-vertical) + 30px) 24px var(--padding-vertical) 24px; }
    }
    """
    }
}
