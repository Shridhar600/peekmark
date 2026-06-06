# Security Policy

PeekMark is a sandboxed macOS application that renders Markdown content through a WKWebView. Security is a priority because the renderer processes untrusted Markdown input.

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Development builds (`main` branch) | ⚠️ Best effort |

## Reporting a Vulnerability

Open a GitHub issue with the **Security** label, or email the maintainers directly. Do not publicly disclose vulnerabilities until they've been addressed.

## Security Model

- **Sandboxed**: The app runs in Apple's App Sandbox with user-selected read-only file access and app-scoped bookmarks.
- **WKWebView CSP**: A strict Content-Security-Policy (`default-src 'none'; script-src 'nonce-<per-render>' 'strict-dynamic'; style-src 'self' 'unsafe-inline'; font-src data:; img-src 'self' data:; connect-src 'none'`) is enforced on all rendered content, blocking all remote script, style, font, XHR, and WebSocket fetches. Inline scripts are bound to a fresh, unguessable **per-render nonce**, so any script injected via crafted Markdown that slips past `HTMLSanitizer` carries no valid nonce and is refused by the renderer — script execution no longer depends on `'unsafe-inline'`.
- **Vendored Renderer Assets**: Highlight.js, KaTeX, and Mermaid are bundled inside the app and extension under `WebAssets/`. There are no CDN fallbacks.
- **Unavoidable Network Entitlement**: The host app declares `com.apple.security.network.client` because `WKWebView`'s separate `WebContent` rendering subprocess requires that entitlement in order to launch on macOS 15+. The host process never opens a network socket and the strict CSP prevents the renderer from making any network request, but the entitlement itself cannot be removed without breaking the preview.
- **User-initiated link clicks**: When the user clicks a link in a rendered Markdown document, PeekMark opens the URL in the system's default browser via `NSWorkspace.shared.open`. This is a user-initiated action, not an automatic network call by the app. PeekMark does not contact third-party hosts on its own.
- **HTML Sanitizer**: All generated HTML passes through `HTMLSanitizer` which strips:
  - `<img src="https?://...">` — remote image fetches (privacy / no third-party contact)
  - `<img src="data:image/svg+xml;…">` — raw SVG data URIs (XSS attack surface, since `data:` is allowed in `img-src` by the CSP)
  - `<img src="local-relative-path">` — local relative images, because PeekMark is sandboxed and only has read access to the user-selected Markdown file. The corresponding `<img>` tags are stripped from the preview to avoid broken-image icons. Inline raster `data:` URIs in the source Markdown are self-contained and are preserved.
  - Remote stylesheets/links, `javascript:` URIs, and event handler attributes.
- **Security-Scoped Bookmarks**: File access outside the sandbox uses macOS security-scoped bookmarks.
- **First Public Release Limitations**: Local relative images are intentionally not rendered. See the README "Limitations" section for the full list.

### Renderer & Network Model

- **Vendored renderer assets** (Highlight.js, KaTeX, Mermaid) live in
  `WebAssets/` inside both the app and Quick Look extension bundles. There
  are no CDN fallbacks. The strict CSP (`default-src 'none'; ...`) prevents
  the WKWebView from making any remote request even if a future bug tried
  to.
- **Unavoidable network entitlement.** The host app declares
  `com.apple.security.network.client` because WKWebView's separate
  `WebContent` rendering subprocess requires that entitlement to launch on
  macOS 15+. The host process itself never opens a network socket.
  Removing the entitlement blanks the preview silently. The strict CSP
  is the defense that actually prevents network egress from the renderer.
- **User-initiated link clicks** go through `NSWorkspace.shared.open` to
  the user's default browser. This is a user-initiated action, not an
  automatic call.
- **Local images.** Local-relative `<img src="…">` and remote `<img>` are
  stripped by `HTMLSanitizer` (see the HTML Sanitizer bullet in
  *Security Model* above). Inline raster `data:` URIs (PNG, JPEG, GIF,
  WebP) are preserved because they are self-contained. Local image
  rendering may be reintroduced via a sandbox-safe mechanism (e.g.
  `loadFileURL` with scoped read access) in a future release.

## What to Report

- HTML injection or XSS via rendered Markdown
- CSP bypass in the WKWebView
- Sandbox escape via the Quick Look extension
- Data URI abuse or local file disclosure
- Any crash triggered by crafted Markdown input
