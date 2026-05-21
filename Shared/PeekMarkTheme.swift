import Foundation

enum MarkdownAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum PeekMarkTheme {
    static func css(for appearance: MarkdownAppearance = .light) -> String {
        switch appearance {
        case .system:
            return css(
                colorScheme: "light dark",
                background: "rgba(255, 255, 255, 0.85)",
                text: "#111111",
                secondaryText: "#333333",
                line: "#d0d0d0",
                softLine: "#e6e6e6",
                codeBackground: "#f5f5f5",
                quoteBackground: "#f7f7f7",
                tableStripe: "#fafafa",
                adaptiveDarkCSS: adaptiveDarkCSS
            )
        case .light:
            return css(
                colorScheme: "light",
                background: "rgba(250, 250, 250, 0.85)",
                text: "#111111",
                secondaryText: "#444444",
                line: "#e0e0e0",
                softLine: "#f0f0f0",
                codeBackground: "#f5f5f5",
                quoteBackground: "#f8f8f8",
                tableStripe: "#fcfcfc",
                adaptiveDarkCSS: ""
            )
        case .dark:
            return css(
                colorScheme: "dark",
                background: "rgba(30, 30, 30, 0.85)",
                text: "#f5f5f5",
                secondaryText: "#b0b0b0",
                line: "#3a3a3a",
                softLine: "#2a2a2a",
                codeBackground: "#252525",
                quoteBackground: "#222222",
                tableStripe: "#1f1f1f",
                adaptiveDarkCSS: ""
            )
        }
    }

    private static var adaptiveDarkCSS: String {
        """

    @media (prefers-color-scheme: dark) {
      :root {
        --background: rgba(30, 30, 30, 0.85);
        --text: #f5f5f5;
        --secondary-text: #b0b0b0;
        --line: #3a3a3a;
        --soft-line: #2a2a2a;
        --code-bg: #252525;
        --quote-bg: #222222;
        --table-stripe: #1f1f1f;
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
        adaptiveDarkCSS: String
    ) -> String {
        """
    :root {
      color-scheme: \(colorScheme);
      --background: \(background);
      --text: \(text);
      --secondary-text: \(secondaryText);
      --line: \(line);
      --soft-line: \(softLine);
      --code-bg: \(codeBackground);
      --quote-bg: \(quoteBackground);
      --table-stripe: \(tableStripe);
    }

    * { box-sizing: border-box; }

    html {
      background: var(--background);
      color: var(--text);
      font: 16px/1.58 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
    }

    body {
      margin: 0;
      padding: 28px;
      background: var(--background);
    }

    main {
      max-width: 840px;
      margin: 0 auto;
      padding: 0;
      background: var(--background);
      color: var(--text);
    }

    h1, h2, h3, h4, h5, h6 {
      line-height: 1.18;
      letter-spacing: 0;
      margin: 1.35em 0 0.45em;
    }

    h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
    h1 { font-size: 2.25rem; }
    h2 { font-size: 1.65rem; padding-bottom: 0.25rem; border-bottom: 1px solid var(--line); }
    h3 { font-size: 1.28rem; }

    p, ul, ol, blockquote, table, pre { margin: 0 0 1rem; }
    a { color: LinkText; text-decoration-thickness: 0.08em; text-underline-offset: 0.18em; }
    img { max-width: 100%; height: auto; }

    blockquote {
      padding: 0.75rem 1rem;
      border-left: 3px solid var(--line);
      background: var(--quote-bg);
      color: var(--secondary-text);
    }

    code {
      padding: 0.15rem 0.32rem;
      border-radius: 3px;
      background: var(--code-bg);
      font: 0.9em/1.45 "SF Mono", Menlo, monospace;
    }

    pre {
      overflow-x: auto;
      padding: 1rem 1.1rem;
      border: 1px solid var(--soft-line);
      border-radius: 4px;
      background: var(--code-bg);
      color: var(--text);
    }

    pre code {
      padding: 0;
      background: transparent;
      color: inherit;
      font-size: 0.9rem;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.93rem;
    }

    th, td {
      padding: 0.55rem 0.7rem;
      border: 1px solid var(--line);
      text-align: left;
      vertical-align: top;
    }

    tr:nth-child(even) td { background: var(--table-stripe); }
    hr { border: 0; border-top: 1px solid var(--line); margin: 1.6rem 0; }
    \(adaptiveDarkCSS)

    @media (prefers-reduced-transparency: reduce) {
      :root {
        --background: #fafafa !important;
      }
      @media (prefers-color-scheme: dark) {
        :root {
          --background: #1e1e1e !important;
        }
      }
    }

    @media (max-width: 720px) {
      body { padding: 20px; }
    }
    """
    }
}
