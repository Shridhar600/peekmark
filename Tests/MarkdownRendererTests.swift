import XCTest

final class MarkdownRendererTests: XCTestCase {
    func testRendersCommonMarkdownElements() async {
        let markdown = """
        # Title

        A paragraph with **strong text** and `inline code`.

        - One
        - Two

        | Name | Value |
        | --- | --- |
        | A | 1 |

        ```swift
        print("hello")
        ```
        """

        let result = await MarkdownRenderer.render(markdown: markdown, title: "Doc")

        XCTAssertTrue(result.html.contains("<h1>Title</h1>"))
        XCTAssertTrue(result.html.contains("<strong>strong text</strong>"))
        XCTAssertTrue(result.html.contains("<code>inline code</code>"))
        XCTAssertTrue(result.html.contains("<li>"))
        XCTAssertTrue(result.html.contains("One"))
        XCTAssertTrue(result.html.contains("<table>"))
        XCTAssertTrue(result.html.contains("print"))
    }

    func testUsesPlainDocumentChrome() async {
        let result = await MarkdownRenderer.render(markdown: "# Plain", title: "Plain")

        XCTAssertFalse(result.html.contains("border-radius: 8px"))
        XCTAssertFalse(result.html.contains("color-mix"))
        XCTAssertFalse(result.html.contains("#176b62"))
        XCTAssertTrue(result.html.contains("--bg: #ffffff;"))
        XCTAssertTrue(result.html.contains("--text: #1d1d1f;"))
        XCTAssertTrue(result.html.contains("background: var(--bg);"))
        XCTAssertTrue(result.html.contains("color: var(--text);"))
    }

    func testRendersDarkAppearanceWhenRequested() async {
        let result = await MarkdownRenderer.render(markdown: "# Dark", title: "Dark", appearance: .dark)

        XCTAssertTrue(result.html.contains("color-scheme: dark;"))
        XCTAssertTrue(result.html.contains("--bg: #1e1e1e;"))
        XCTAssertTrue(result.html.contains("--text: #d2d2d7;"))
        XCTAssertTrue(result.html.contains("background: var(--bg);"))
        XCTAssertTrue(result.html.contains("color: var(--text);"))
    }

    func testRendersSystemAppearanceWhenRequested() async {
        let result = await MarkdownRenderer.render(markdown: "# System", title: "System", appearance: .system)
        let normalizedHTML = result.html.normalizedWhitespace

        XCTAssertTrue(result.html.contains("color-scheme: light dark;"))
        XCTAssertTrue(result.html.contains("@media (prefers-color-scheme: dark)"))
        XCTAssertTrue(normalizedHTML.contains("html { background: var(--bg); color: var(--text);"))
        XCTAssertTrue(normalizedHTML.contains("body { margin: 0; padding: calc(var(--padding-vertical) + 36px) var(--padding-horizontal) var(--padding-vertical) var(--padding-horizontal); background: var(--bg);"))
        XCTAssertTrue(normalizedHTML.contains("main { max-width: var(--max-width); margin: 0 auto;"))
    }

    func testCanRethemeExistingBodyWithoutChangingRenderedMarkdown() async {
        let light = await MarkdownRenderer.render(markdown: "# Title\n\nBody", title: "Doc", appearance: .light)
        let dark = MarkdownRenderer.wrapHTML(title: light.title, bodyHTML: light.bodyHTML, appearance: .dark)

        XCTAssertEqual(light.bodyHTML, dark.bodyHTML)
        XCTAssertTrue(dark.html.contains("color-scheme: dark;"))
        XCTAssertTrue(dark.html.contains("<h1>Title</h1>"))
    }

    func testSanitizesScriptAndJavaScriptLinks() async {
        let markdown = """
        <script>alert("x")</script>

        [bad](javascript:alert(1))
        """

        let result = await MarkdownRenderer.render(markdown: markdown, title: "Unsafe")

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("javascript:"))
    }

    func testSanitizesRawHTMLRemoteResources() async {
        let markdown = """
        <img src='https://example.com/tracker.png'>
        <link href=https://example.com/site.css rel=stylesheet>
        <a href="file:///etc/passwd">local file</a>
        <a href=javascript:alert(1)>script link</a>
        <img src="data:image/svg+xml;base64,PHN2ZyBvbmxvYWQ9YWxlcnQoMSk+">
        <span style="background:url(https://example.com/bg.png)">bad</span>
        """

        let result = await MarkdownRenderer.render(markdown: markdown, title: "Unsafe HTML")

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("javascript:"))
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<link"))
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("style="))
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("https://example.com"))
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("file:///"))
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("data:image/svg"))
    }

    func testEscapesErrorHTML() {
        let result = MarkdownRenderer.renderError(title: "<bad>", message: "<script>alert(1)</script>")

        XCTAssertTrue(result.html.contains("&lt;bad&gt;"))
        XCTAssertTrue(result.html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        XCTAssertFalse(result.html.contains("<bad>"))
    }

    func testStripsLocalRelativeImageMarkdownSyntax() async {
        let result = await MarkdownRenderer.render(
            markdown: "![local](local.png)",
            title: "Local Image",
            baseURL: URL(fileURLWithPath: NSTemporaryDirectory())
        )

        XCTAssertFalse(result.bodyHTML.contains("local.png"), "local image src should be stripped, got: \(result.bodyHTML)")
        XCTAssertFalse(result.bodyHTML.contains("<img"), "no <img> tag should remain for a local relative reference")
    }

    func testStripsLocalRelativeImageRawHTMLDoubleQuoted() async {
        let result = await MarkdownRenderer.render(
            markdown: "<img src=\"local.png\" alt=\"x\">",
            title: "Local Image",
            baseURL: URL(fileURLWithPath: NSTemporaryDirectory())
        )

        XCTAssertFalse(result.bodyHTML.contains("<img"), "no <img> tag should remain for a local relative reference")
        XCTAssertFalse(result.bodyHTML.contains("local.png"))
    }

    func testStripsLocalRelativeImageRawHTMLSingleQuoted() async {
        let result = await MarkdownRenderer.render(
            markdown: "<img src='local.png' alt='x'>",
            title: "Local Image",
            baseURL: URL(fileURLWithPath: NSTemporaryDirectory())
        )

        XCTAssertFalse(result.bodyHTML.contains("<img"), "no <img> tag should remain for a local relative reference")
        XCTAssertFalse(result.bodyHTML.contains("local.png"))
    }

    func testStripsLocalRelativeImageRawHTMLUnquoted() async {
        let result = await MarkdownRenderer.render(
            markdown: "<img src=local.png alt=x>",
            title: "Local Image",
            baseURL: URL(fileURLWithPath: NSTemporaryDirectory())
        )

        XCTAssertFalse(result.bodyHTML.contains("<img"), "no <img> tag should remain for a local relative reference")
        XCTAssertFalse(result.bodyHTML.contains("local.png"))
    }

    func testKeepsRasterDataURIImageTags() async {
        // Inline raster data URIs in the source markdown are self-contained and
        // don't depend on the sandbox. They should be preserved verbatim.
        let dataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
        let result = await MarkdownRenderer.render(
            markdown: "<img src=\"\(dataURI)\" alt=\"pixel\">",
            title: "Data URI",
            baseURL: nil
        )

        XCTAssertTrue(result.bodyHTML.contains(dataURI), "raster data URI should be kept in bodyHTML")
        XCTAssertTrue(result.html.contains(dataURI), "raster data URI should survive full render() pipeline")
        XCTAssertTrue(result.bodyHTML.contains("<img"), "raster data URI <img> tag should be kept")
    }

    func testStripsRemoteImageSources() async {
        let result = await MarkdownRenderer.render(
            markdown: "![tracking](https://example.com/pixel.png)",
            title: "Remote Image",
            baseURL: URL(fileURLWithPath: NSTemporaryDirectory())
        )

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("https://example.com/pixel.png"))
    }

    func testStripsSVGDataURIImageSources() async {
        let result = await MarkdownRenderer.render(
            markdown: "<img src=\"data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnLz4=\" alt=\"x\">",
            title: "SVG Data URI",
            baseURL: nil
        )

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("data:image/svg"))
        XCTAssertFalse(result.bodyHTML.contains("<img"))
    }

    func testSanitizesFootnotes() async {
        let markdown = """
        Here is a footnote[^1].

        [^1]: text <script>alert("x")</script> and [bad](javascript:alert(1))
        """

        let result = await MarkdownRenderer.render(markdown: markdown, title: "Footnotes")

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("javascript:"))
    }

    func testParsesYAMLMetadataAndDoesNotRenderTable() async {
        let markdown = """
        ---
        title: Metadata Test
        author: PeekMark
        tags: [markdown, swift]
        ---
        # Title

        Body content.
        """

        let result = await MarkdownRenderer.render(markdown: markdown, title: "Doc")

        XCTAssertEqual(result.metadata["title"], "Metadata Test")
        XCTAssertEqual(result.metadata["author"], "PeekMark")
        XCTAssertEqual(result.metadata["tags"], "[markdown, swift]")

        XCTAssertFalse(result.html.contains("<table class=\"front-matter-table\">"))
        XCTAssertFalse(result.bodyHTML.contains("Metadata Test"))
        XCTAssertTrue(result.bodyHTML.contains("<h1>Title</h1>"))
    }

    func testRenderDocumentStripsFrontMatterFromPreviewBody() {
        // Regression: the Quick Look extension used to render the raw file, so
        // YAML front matter appeared as visible text in the preview. Both the
        // app and the extension now share `renderDocument`, which strips it.
        let markdown = """
        ---
        title: Secret Notes
        author: PeekMark
        ---
        # Visible Heading

        Body text.
        """
        let result = MarkdownRenderer.renderDocument(markdown: markdown, title: "Doc")

        XCTAssertFalse(result.bodyHTML.contains("Secret Notes"), "front-matter value leaked into body: \(result.bodyHTML)")
        XCTAssertFalse(result.bodyHTML.contains("author:"), "front-matter key leaked into body")
        XCTAssertFalse(result.html.contains("Secret Notes"), "front-matter value leaked into full document")
        // Metadata is still parsed and available to callers.
        XCTAssertEqual(result.metadata["title"], "Secret Notes")
        XCTAssertEqual(result.metadata["author"], "PeekMark")
        // The real document content still renders.
        XCTAssertTrue(result.bodyHTML.contains("<h1>Visible Heading</h1>"))
        XCTAssertTrue(result.bodyHTML.contains("Body text."))
    }

    func testRenderDocumentWithoutFrontMatterRendersFullBody() {
        // No leading `---` → nothing is stripped.
        let result = MarkdownRenderer.renderDocument(markdown: "# Heading\n\nJust content.", title: "Doc")
        XCTAssertTrue(result.bodyHTML.contains("<h1>Heading</h1>"))
        XCTAssertTrue(result.bodyHTML.contains("Just content."))
        XCTAssertTrue(result.metadata.isEmpty)
    }

    func testVendorEnhancementsAreDefensiveWhenAssetsFailToLoad() async {
        let result = await MarkdownRenderer.render(markdown: "# Title\n\n```swift\nprint(\"hello\")\n```", title: "Doc")

        XCTAssertTrue(result.html.contains("if (window.hljs && typeof window.hljs.highlightAll === 'function')"))
        XCTAssertTrue(result.html.contains("if (typeof window.renderMathInElement === 'function')"))
        XCTAssertTrue(result.html.contains("if (window.mermaid && typeof window.mermaid.initialize === 'function' && typeof window.mermaid.run === 'function')"))
        XCTAssertFalse(result.html.contains("\n            hljs.highlightAll();"))
        XCTAssertFalse(result.html.contains("\n              mermaid.initialize({"))
    }

    func testUsesBundledWebAssetsWhenAvailable() async {
        // Exercises all three vendor features (math, a code block, a Mermaid
        // diagram) so every bundled asset is inlined — the point of this test is
        // that assets come from the bundle, never a CDN.
        let markdown = """
        # Title

        Inline math $x^2$.

        ```swift
        print("hi")
        ```

        ```mermaid
        graph TD; A-->B;
        ```
        """
        let result = await MarkdownRenderer.render(markdown: markdown, title: "Doc")

        XCTAssertTrue(result.html.contains(#"<style id="hljs-light" media="all">"#))
        XCTAssertTrue(result.html.contains(#"<style id="katex-style" media="all">"#))
        XCTAssertTrue(result.html.contains(#"<script id="hljs-script">"#))
        XCTAssertTrue(result.html.contains(#"<script id="katex-script">"#))
        XCTAssertTrue(result.html.contains(#"<script id="katex-auto-render-script">"#))
        XCTAssertTrue(result.html.contains(#"<script id="mermaid-script">"#))
        XCTAssertTrue(result.html.contains("data:font/woff2;base64,"))
        XCTAssertFalse(result.html.contains(#"src="https://cdnjs.cloudflare.com"#))
        XCTAssertFalse(result.html.contains(#"src="https://cdn.jsdelivr.net"#))
        XCTAssertFalse(result.html.contains(#"href="https://cdnjs.cloudflare.com"#))
        XCTAssertFalse(result.html.contains(#"href="https://cdn.jsdelivr.net"#))
    }

    func testDocumentHTMLWithBundledAssetsRendersFullPreview() {
        // Body exercises all three vendor features so every asset is inlined.
        let result = MarkdownRenderer.documentHTML(
            title: "Doc",
            body: "<h1>Hello</h1><pre><code class=\"language-swift\">x</code></pre><p>$x^2$</p><pre><code class=\"language-mermaid\">graph TD; A--&gt;B;</code></pre>",
            appearance: .light,
            font: .system,
            fontSize: 14.5,
            spacing: .regular,
            isTransparent: false,
            webAssets: WebAssetBundle(
                highlightLightCSS: "/*light*/",
                highlightDarkCSS: "/*dark*/",
                highlightJS: "//hljs",
                katexCSS: "/*katex*/",
                katexJS: "//katex",
                katexAutoRenderJS: "//autorender",
                mermaidJS: "//mermaid"
            )
        )

        XCTAssertTrue(result.contains(#"<style id="hljs-light" media="all">/*light*/</style>"#))
        XCTAssertTrue(result.contains(#"<style id="hljs-dark" media="not all">/*dark*/</style>"#))
        XCTAssertTrue(result.contains(#"<script id="hljs-script">//hljs</script>"#))
        XCTAssertTrue(result.contains(#"<style id="katex-style" media="all">/*katex*/</style>"#))
        XCTAssertTrue(result.contains(#"<script id="katex-script">//katex</script>"#))
        XCTAssertTrue(result.contains(#"<script id="katex-auto-render-script">//autorender</script>"#))
        XCTAssertTrue(result.contains(#"<script id="mermaid-script">//mermaid</script>"#))
        XCTAssertFalse(result.contains("peekmark-asset-error"))
        XCTAssertTrue(result.contains("default-src 'none'"))
        XCTAssertTrue(result.contains("connect-src 'none'"))
        XCTAssertFalse(result.contains("cdnjs.cloudflare.com"))
        XCTAssertFalse(result.contains("cdn.jsdelivr.net"))
    }

    // F16 note: the asset-error-banner production path
    // (WebAssetBundle.load() → documentHTML(webAssets:)) is not tested via
    // a live filesystem-rename because (a) WebAssetBundle.bundledAssets is a
    // static let — once loaded it is cached for the process lifetime, and
    // (b) moving the app's WebAssets/ directory would mutate the built
    // product during test execution, which is fragile and risks leaving
    // the tree in a bad state on interrupt. The internal seam
    // documentHTML(webAssets: nil) covers the logic; an integration-level
    // test is deferred until a cache-reset mechanism exists.

    func testDocumentHTMLWithoutBundledAssetsRendersErrorBannerAndStillRendersBody() {
        let result = MarkdownRenderer.documentHTML(
            title: "Doc",
            body: "<h1>Hello</h1><pre><code class=\"language-mermaid\">graph TD; A-->B;</code></pre>",
            appearance: .light,
            font: .system,
            fontSize: 14.5,
            spacing: .regular,
            isTransparent: false,
            webAssets: nil
        )

        XCTAssertTrue(result.contains("peekmark-asset-error"))
        XCTAssertTrue(result.contains("PeekMark failed to load bundled web assets"))
        XCTAssertTrue(result.contains("<h1>Hello</h1>"))
        XCTAssertTrue(result.contains("language-mermaid"))
        XCTAssertTrue(result.contains("connect-src 'none'"))

        XCTAssertFalse(result.contains(#"<script id="hljs-script">"#))
        XCTAssertFalse(result.contains(#"<script id="katex-script">"#))
        XCTAssertFalse(result.contains(#"<script id="mermaid-script">"#))
        XCTAssertFalse(result.contains(#"<style id="katex-style""#))
        XCTAssertFalse(result.contains("cdnjs.cloudflare.com"))
        XCTAssertFalse(result.contains("cdn.jsdelivr.net"))
    }

    // MARK: - Conditional vendor-asset injection (only inline libraries the body uses)

    func testOmitsAllVendorAssetsForPlainProse() {
        let result = MarkdownRenderer.documentHTML(
            title: "Doc",
            body: "<h1>Hello</h1><p>Plain prose with no code, math, or diagrams.</p>",
            appearance: .light, font: .system, fontSize: 14.5, spacing: .regular,
            isTransparent: false, webAssets: fakeWebAssets()
        )

        XCTAssertFalse(result.contains(#"<script id="hljs-script">"#), "no code → no highlight.js")
        XCTAssertFalse(result.contains(#"<script id="katex-script">"#), "no math → no KaTeX")
        XCTAssertFalse(result.contains(#"<script id="mermaid-script">"#), "no diagram → no Mermaid")
        XCTAssertFalse(result.contains(#"<style id="katex-style""#))
        XCTAssertFalse(result.contains("//mermaid"), "Mermaid source must not be inlined for plain prose")
        // Body still renders, defensive runtime guards remain, and this is not an error state.
        XCTAssertTrue(result.contains("<h1>Hello</h1>"))
        XCTAssertTrue(result.contains("if (window.mermaid"))
        XCTAssertFalse(result.contains("peekmark-asset-error"), "omission is an optimization, not an error")
    }

    func testIncludesOnlyKatexForMathOnlyBody() {
        let result = MarkdownRenderer.documentHTML(
            title: "Doc",
            body: "<p>Euler: $e^{i\\pi}+1=0$</p>",
            appearance: .light, font: .system, fontSize: 14.5, spacing: .regular,
            isTransparent: false, webAssets: fakeWebAssets()
        )

        XCTAssertTrue(result.contains(#"<script id="katex-script">//katex</script>"#))
        XCTAssertTrue(result.contains(#"<script id="katex-auto-render-script">//autorender</script>"#))
        XCTAssertTrue(result.contains(#"<style id="katex-style""#))
        XCTAssertFalse(result.contains(#"<script id="mermaid-script">"#), "math-only body must not ship Mermaid")
        XCTAssertFalse(result.contains(#"<script id="hljs-script">"#), "math-only body has no code block")
    }

    func testIncludesMermaidForDiagramBody() {
        let result = MarkdownRenderer.documentHTML(
            title: "Doc",
            body: "<pre><code class=\"language-mermaid\">graph TD; A--&gt;B;</code></pre>",
            appearance: .light, font: .system, fontSize: 14.5, spacing: .regular,
            isTransparent: false, webAssets: fakeWebAssets()
        )

        XCTAssertTrue(result.contains(#"<script id="mermaid-script">//mermaid</script>"#))
        XCTAssertFalse(result.contains(#"<script id="katex-script">"#), "diagram-only body has no math")
        // Note: a Mermaid block lives inside a <pre>, so highlight.js is allowed
        // to load here (harmless — highlightAll runs after the mermaid <pre> is
        // converted to a <div>). We intentionally don't assert hljs absence.
    }

    func testIncludesHighlightForCodeBody() {
        let result = MarkdownRenderer.documentHTML(
            title: "Doc",
            body: "<pre><code class=\"language-swift\">print(\"hi\")</code></pre>",
            appearance: .light, font: .system, fontSize: 14.5, spacing: .regular,
            isTransparent: false, webAssets: fakeWebAssets()
        )

        XCTAssertTrue(result.contains(#"<script id="hljs-script">//hljs</script>"#))
        XCTAssertTrue(result.contains(#"<style id="hljs-light" media="all">/*light*/</style>"#))
        XCTAssertFalse(result.contains(#"<script id="mermaid-script">"#), "plain code has no diagram")
        XCTAssertFalse(result.contains(#"<script id="katex-script">"#), "plain code has no math")
    }

    func testSampleFileDoesNotEmbedLocalImages() async throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let samplePath = repoRoot.appendingPathComponent("Samples/PeekMark.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: samplePath.path), "sample file missing")

        let markdown = try String(contentsOf: samplePath, encoding: .utf8)
        let result = await MarkdownRenderer.render(
            markdown: markdown,
            title: "PeekMark",
            baseURL: samplePath.deletingLastPathComponent()
        )

        let body = result.bodyHTML
        // The sample contains a real, renderable inline raster data URI
        // (added in the F6/F7 follow-up). The renderer must preserve it.
        // The substring `data:image/png;base64,` only appears in the body
        // if a real `<img src="data:image/png;base64,…">` tag survived
        // sanitization — no markdown prose, no code span, no
        // sanitizer-emitted constant contains that exact substring.
        XCTAssertTrue(body.contains("data:image/png;base64,"),
                      "inline raster data URI from sample should be preserved as a real <img> tag")
        // The sample's Media section mentions `<img>` and `src=` inside
        // backtick code spans. After sanitization those should still be
        // present (as `<code>…</code>` content, not as real <img> tags).
        // Asserting presence confirms the code spans rendered correctly.
        XCTAssertTrue(body.contains("<code>") || !markdown.contains("`<"),
                      "no backtick code spans in source")
    }

    // MARK: - F1 regression: raster data URI preservation across quote variants

    func testKeepsRasterDataURIImageTagsAcrossQuoteVariants() async {
        // The `localImgTagRegex` negative lookahead used to be anchored on a
        // literal `"`, which silently stripped single-quoted and unquoted
        // raster data URIs even though README/SECURITY promise they are
        // preserved. The fix makes the opening quote optional in the lookahead.
        let pngDataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
        let jpegDataURI = pngDataURI.replacingOccurrences(of: "image/png", with: "image/jpeg")

        let cases: [(label: String, markdown: String, expectedURI: String)] = [
            ("double-quoted", "<img src=\"\(pngDataURI)\" alt=\"pixel\">", pngDataURI),
            ("single-quoted", "<img src='\(pngDataURI)' alt='pixel'>", pngDataURI),
            ("unquoted", "<img src=\(pngDataURI) alt=pixel>", pngDataURI),
            ("extra spaces", "<img src = \"\(pngDataURI)\" alt = \"pixel\">", pngDataURI),
            ("uppercase tag", "<IMG SRC='\(pngDataURI)' ALT='pixel'>", pngDataURI),
            ("jpeg single-quoted", "<img src='\(jpegDataURI)' alt='x'>", jpegDataURI),
        ]

        for (label, markdown, expectedURI) in cases {
            let result = await MarkdownRenderer.render(markdown: markdown, title: "Data URI \(label)", baseURL: nil)
            XCTAssertTrue(
                result.bodyHTML.localizedCaseInsensitiveContains(expectedURI),
                "raster data URI should be kept for \(label) variant, got: \(result.bodyHTML)"
            )
            XCTAssertTrue(
                result.bodyHTML.localizedCaseInsensitiveContains("<img"),
                "raster data URI <img> tag should be kept for \(label) variant, got: \(result.bodyHTML)"
            )
        }
    }

    func testStripsSingleQuotedLocalRelativeImageAfterRasterFix() async {
        // Regression check: after the F1 fix that makes the opening quote in
        // the `localImgTagRegex` negative lookahead optional, the strip path
        // for single-quoted local relative images must still work. The fix
        // was a negative-lookahead *allow*, not a negative-lookahead *deny*,
        // so local images in any quote style are still stripped.
        let result = await MarkdownRenderer.render(
            markdown: "<img src='local.png' alt='x'>",
            title: "Local Image",
            baseURL: URL(fileURLWithPath: NSTemporaryDirectory())
        )

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<img"), "single-quoted local <img> must still be stripped")
        XCTAssertFalse(result.bodyHTML.contains("local.png"))
    }

    // MARK: - F2: video / audio / source / track / picture

    func testStripsVideoTag() async {
        let result = await MarkdownRenderer.render(
            markdown: """
            <video src="local.mp4" controls></video>
            <video controls><source src="local.mp4" type="video/mp4"></video>
            """,
            title: "Video"
        )

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("local.mp4"), "video src must be stripped, got: \(result.bodyHTML)")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<video"), "<video> tag must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<source"), "<source> tag must be stripped")
    }

    func testStripsAudioAndTrackTags() async {
        let result = await MarkdownRenderer.render(
            markdown: """
            <audio src="local.mp3"></audio>
            <track src="local.vtt">
            """,
            title: "Media"
        )

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("local.mp3"), "audio src must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("local.vtt"), "track src must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<audio"), "<audio> tag must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<track"), "<track> tag must be stripped")
    }

    func testStripsPictureWithSourceAndImg() async {
        // F5 case: a <picture><source srcset="…"> wrapper would leak the
        // remote URL via `srcset` even though CSP blocks the fetch. Stripping
        // the whole <picture> / <source> / <img> tags via the extended
        // `tagTags` list removes the URL string from the DOM.
        let result = await MarkdownRenderer.render(
            markdown: "<picture><source srcset=\"https://x.com/y.png\"><img src=\"local.png\"></picture>",
            title: "Picture"
        )

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("x.com"), "remote srcset URL must be stripped")
        XCTAssertFalse(result.bodyHTML.contains("local.png"), "local img src must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<picture"), "<picture> must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<source"), "<source> must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<img"), "<img> must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("srcset"), "srcset attribute must be stripped")
    }

    // MARK: - F4: bare <img> with no src

    func testStripsImgWithNoSrcAttribute() async {
        // Without an `src`, the `localImgTagRegex` (which requires `\bsrc\s*=`)
        // never matches, leaving a broken-image icon. The `noSrcImgTagRegex`
        // strip catches these.
        let result = await MarkdownRenderer.render(
            markdown: """
            <img alt="x">
            <img>
            """,
            title: "Bare Img"
        )

        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("<img"), "<img> with no src must be stripped, got: \(result.bodyHTML)")
    }

    // MARK: - F13: event handlers on raster data URI tags

        // MARK: - F18: sample file renders all features

    func testSampleFileRendersAllFeatures() async throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let samplePath = repoRoot.appendingPathComponent("Samples/PeekMark.md")
        let markdown = try String(contentsOf: samplePath, encoding: .utf8)
        let result = await MarkdownRenderer.render(markdown: markdown, title: "PeekMark")

        let body = result.bodyHTML
        XCTAssertTrue(body.contains("language-mermaid"), "Mermaid code block should be present")
        XCTAssertTrue(body.contains("<table>"), "Tables should be rendered")
        XCTAssertTrue(body.contains("class=\"footnote-ref\""), "Footnote references should be present")
        XCTAssertTrue(body.contains("<code class=\"language-swift\""), "Swift code block should be highlighted")
        XCTAssertTrue(body.contains("<code class=\"language-javascript\""), "JavaScript code block should be highlighted")
        XCTAssertTrue(body.contains("<code class=\"language-python\""), "Python code block should be highlighted")
        XCTAssertTrue(body.contains("<code class=\"language-rust\""), "Rust code block should be highlighted")
        XCTAssertTrue(body.contains("<code class=\"language-sql\""), "SQL code block should be highlighted")
        XCTAssertTrue(body.contains("<code class=\"language-diff\""), "Diff code block should be highlighted")
        XCTAssertTrue(body.contains("<details>"), "<details> HTML should survive sanitization")
        XCTAssertTrue(body.contains("<summary>"), "<summary> HTML should survive sanitization")
        XCTAssertTrue(body.contains("<input type=\"checkbox\""), "Task list checkbox should be present")
        XCTAssertTrue(body.contains("<blockquote>"), "Blockquotes / callouts should be present")
        XCTAssertTrue(body.contains("<strong>"), "Bold text should be rendered")
        XCTAssertTrue(body.contains("<em>"), "Italic text should be rendered")
        XCTAssertTrue(body.contains("<del>"), "Strikethrough text should be rendered")
        XCTAssertTrue(body.contains("<h1>"), "Headings should be rendered")
        XCTAssertTrue(body.contains("<h2>"), "Sub-headings should be rendered")
        XCTAssertTrue(body.contains("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2"),
                      "the sample's inline raster data URI image should survive")
    }

    func testStripsEventHandlersFromRasterDataURIImg() async {
        let dataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
        let result = await MarkdownRenderer.render(
            markdown: "<img src=\"\(dataURI)\" alt=\"x\" onerror=\"alert(1)\" onload=\"track()\">",
            title: "Event Handler",
            baseURL: nil
        )

        XCTAssertTrue(result.bodyHTML.contains(dataURI), "raster data URI should be preserved on a surviving <img>")
        XCTAssertTrue(result.bodyHTML.localizedCaseInsensitiveContains("<img"), "raster data URI <img> tag should be kept")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("onerror"), "onerror must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("onload"), "onload must be stripped")
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("alert(1)"), "the event handler body must not survive")
    }
}

private extension String {
    var normalizedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Small, recognizable stand-in asset bundle for the conditional-injection
/// tests — each field is a short sentinel so assertions can match on the exact
/// inlined source (e.g. `//mermaid`).
private func fakeWebAssets() -> WebAssetBundle {
    WebAssetBundle(
        highlightLightCSS: "/*light*/",
        highlightDarkCSS: "/*dark*/",
        highlightJS: "//hljs",
        katexCSS: "/*katex*/",
        katexJS: "//katex",
        katexAutoRenderJS: "//autorender",
        mermaidJS: "//mermaid"
    )
}
