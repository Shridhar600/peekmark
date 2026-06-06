# Limitations

This document lists what PeekMark intentionally does **not** support in the first public release. Each limitation is either a privacy-by-design choice, a sandbox-imposed constraint, or a packaging decision for the free release. None are bugs.

## Content

### No local image rendering
PeekMark runs inside the macOS App Sandbox. When you open a Markdown file, the app only has read access to that single file, not to sibling images next to it. The supported way to embed an image is an **inline raster `data:` URI** (PNG, JPEG, GIF, or WebP) — those are self-contained and don't depend on the sandbox.

Local image rendering may be reintroduced in a future release via a sandbox-safe mechanism (e.g. `WKWebView.loadFileURL` with scoped read access).

### No remote image fetching
The strict Content-Security-Policy and the `HTMLSanitizer` together block all `https://` / `http://` / `data:image/svg+xml,…` references. This is intentional — opening a Markdown file must not cause PeekMark to contact a third-party host or leak the document's existence, the user's IP, or local timing.

Raw HTML `<img src="https://…">` tags are stripped from the rendered DOM before the page reaches the WKWebView.

### No video / audio / `<iframe>`
Raw HTML `<video>`, `<source>`, `<audio>`, `<track>`, `<picture>`, and `<iframe>` tags are sanitized in the same way as image tags. CSP `default-src 'none'` blocks the actual media load, and the tags themselves are stripped from the DOM so that remote URLs do not appear in the rendered output.

### No notarized `.app` distribution
The build pipeline produces an ad-hoc signed `.app` intended to be installed from `./script/install.sh` or built locally. There is no signed-and-notarized public binary to download. See [`SECURITY.md`](SECURITY.md) for the entitlement audit and the rationale for the unavoidable `com.apple.security.network.client` entitlement.

## Why these aren't bugs

Each of the four items above is a deliberate trade-off documented in the project's [README](README.md) and [SECURITY.md](SECURITY.md). If you need any of them lifted, open an issue on the GitHub repository with a clear use case.
