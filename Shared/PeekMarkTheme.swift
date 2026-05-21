import Foundation

enum MarkdownAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
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
    static func css(
        for appearance: MarkdownAppearance = .system,
        font: PreviewFont = .system,
        fontSize: Double = 14.5,
        spacing: PreviewSpacing = .regular
    ) -> String {
        switch appearance {
        case .system:
            return css(
                colorScheme: "light dark",
                background: "#ffffff",
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
                adaptiveDarkCSS: adaptiveDarkCSS
            )
        case .light:
            return css(
                colorScheme: "light",
                background: "#ffffff",
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
            return css(
                colorScheme: "dark",
                background: "#1e1e1e",
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
    }

    private static var adaptiveDarkCSS: String {
        """

    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #1e1e1e;
        --text: #d2d2d7;
        --secondary-text: #86868b;
        --line: #323236;
        --soft-line: #2c2c30;
        --code-bg: #2c2c30;
        --quote-bg: #2c2c30;
        --table-stripe: #1c1c1e;
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
        let paddingVertical = Int(max(16, fontSize * 1.4))
        let paddingHorizontal = Int(max(24, fontSize * 1.8))
        let maxWidth = Int(fontSize * 48)
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
    }

    * { box-sizing: border-box; }

    html, body {
      max-width: 100%;
      overflow-x: hidden;
    }

    html {
      background: transparent;
      color: var(--text);
      font-family: var(--font-family);
      font-size: var(--font-size);
      line-height: var(--line-height);
    }

    body {
      margin: 0;
      padding: \(paddingVertical + 36)px \(paddingHorizontal)px \(paddingVertical)px \(paddingHorizontal)px;
      background: transparent;
    }

    main {
      max-width: \(maxWidth)px;
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
    a { color: LinkText; text-decoration-thickness: 0.08em; text-underline-offset: 0.18em; }
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

    \(adaptiveDarkCSS)

    @media (max-width: 800px) {
      body { padding: \(paddingVertical + 30)px 24px \(paddingVertical)px 24px; }
    }
    """
    }
}
