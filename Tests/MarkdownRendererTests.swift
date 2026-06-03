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

    func testDoesNotEmbedSymlinkEscapingDocumentDirectory() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let docDirectory = root.appendingPathComponent("doc", isDirectory: true)
        let outsideDirectory = root.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: docDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)

        let outsideImage = outsideDirectory.appendingPathComponent("secret.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: outsideImage)
        let symlink = docDirectory.appendingPathComponent("leak.png")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outsideImage)

        let result = await MarkdownRenderer.render(markdown: "![leak](leak.png)", title: "Image", baseURL: docDirectory)

        XCTAssertFalse(result.html.contains("src=\"data:image/png;base64,"))
    }

    func testEscapesErrorHTML() {
        let result = MarkdownRenderer.renderError(title: "<bad>", message: "<script>alert(1)</script>")

        XCTAssertTrue(result.html.contains("&lt;bad&gt;"))
        XCTAssertTrue(result.html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        XCTAssertFalse(result.html.contains("<bad>"))
    }

    func testEmbedsRelativeImageAsDataURI() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let imageURL = directory.appendingPathComponent("dot.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)

        let result = await MarkdownRenderer.render(markdown: "![dot](dot.png)", title: "Image", baseURL: directory)

        XCTAssertTrue(result.html.contains("src=\"data:image/png;base64,"))
    }

    func testDoesNotEmbedRelativeSVGAsDataURI() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let imageURL = directory.appendingPathComponent("active.svg")
        try "<svg onload=\"alert(1)\"></svg>".data(using: .utf8)!.write(to: imageURL)

        let result = await MarkdownRenderer.render(markdown: "![active](active.svg)", title: "Image", baseURL: directory)

        XCTAssertFalse(result.html.contains("data:image/svg+xml"))
    }

    func testStopsEmbeddingImagesAfterAggregateLimit() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let imageData = Data(repeating: 0x41, count: 4 * 1024 * 1024)
        for index in 1...4 {
            try imageData.write(to: directory.appendingPathComponent("image-\(index).png"))
        }

        let markdown = (1...4)
            .map { "![image-\($0)](image-\($0).png)" }
            .joined(separator: "\n")

        let result = await MarkdownRenderer.render(markdown: markdown, title: "Images", baseURL: directory)
        let embeddedImageCount = result.html.components(separatedBy: "src=\"data:image/png;base64,").count - 1

        XCTAssertEqual(embeddedImageCount, 3)
    }

    func testStripsRemoteImageSources() async {
        let result = await MarkdownRenderer.render(
            markdown: "![tracking](https://example.com/pixel.png)",
            title: "Remote Image",
            baseURL: URL(fileURLWithPath: NSTemporaryDirectory())
        )

        XCTAssertFalse(result.bodyHTML.contains("data:image/"))
        XCTAssertFalse(result.bodyHTML.localizedCaseInsensitiveContains("https://example.com/pixel.png"))
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

    func testVendorEnhancementsAreDefensiveWhenAssetsFailToLoad() async {
        let result = await MarkdownRenderer.render(markdown: "# Title\n\n```swift\nprint(\"hello\")\n```", title: "Doc")

        XCTAssertTrue(result.html.contains("if (window.hljs && typeof window.hljs.highlightAll === 'function')"))
        XCTAssertTrue(result.html.contains("if (typeof window.renderMathInElement === 'function')"))
        XCTAssertTrue(result.html.contains("if (window.mermaid && typeof window.mermaid.initialize === 'function' && typeof window.mermaid.run === 'function')"))
        XCTAssertFalse(result.html.contains("\n            hljs.highlightAll();"))
        XCTAssertFalse(result.html.contains("\n              mermaid.initialize({"))
    }

    func testUsesBundledWebAssetsWhenAvailable() async {
        let result = await MarkdownRenderer.render(markdown: "# Title\n\nInline math $x^2$.", title: "Doc")

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
}

private extension String {
    var normalizedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
