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
- **WKWebView CSP**: A strict Content-Security-Policy is enforced on all rendered content.
- **HTML Sanitizer**: All generated HTML passes through `HTMLSanitizer` which strips remote resources, `javascript:` URIs, and potentially unsafe HTML constructs.
- **Pinned Remote Renderer Assets**: The current renderer loads KaTeX, Mermaid, and Highlight.js from CDN URLs with SRI hashes. Fully vendored offline assets are planned but not currently implemented.
- **Security-Scoped Bookmarks**: File access outside the sandbox uses macOS security-scoped bookmarks.

## What to Report

- HTML injection or XSS via rendered Markdown
- CSP bypass in the WKWebView
- Sandbox escape via the Quick Look extension
- Data URI abuse or local file disclosure
- Any crash triggered by crafted Markdown input
