# Changelog

All notable changes to PeekMark will be documented in this file.

## Unreleased

### Added
- HTML sanitizer for generated content (footnotes, remote URL stripping)
- CSS cache by style parameters for reduced regeneration
- `nonisolated(unsafe)` annotations for QuickLook extension Sendable conformance
- `@MainActor` isolation on `MarkdownAppearance.resolved`
- `OSAllocatedUnfairLock` for thread-safe continuation completion
- Vendored web assets directory structure (`WebAssets/`)

### Fixed
- Search highlighting JS: `queryLower` → `query.toLowerCase()` undefined variable
- Swift 6 concurrency warnings: Sendable closures, actor isolation, deprecated API usage
- Footnote HTML now sanitized before rendering
- Mermaid `securityLevel` changed to `strict` (was `'loose'`)
- QuickLook extension compile warnings for NSAppearance cross-thread capture
- `evaluateJavaScript` callback/deprecation warnings

### Changed
- Strict CSP: removed CDN allowlist (preparation for local asset bundling)
- `withCheckedContinuation` timeout pattern uses `OSAllocatedUnfairLock`
- Default packaged build configuration: `Release`
- Rewrote `openwith_ui_check.sh` for current UI patterns
- Cleaned install/uninstall scripts (removed internal logging references)

### Removed
- Internal docs from tracking (`PeekMark.xcodeproj/` gitignored)
- Internal development docs and audit files
- Stale grep patterns from packaging checks

## 2026-05-27

### Added
- MIT LICENSE file
- Homebrew Cask file

### Security
- Fixed ReDoS in HTMLSanitizer regex (possessive quantifiers)
- MIME type validation for local image embedding
- Tightened CSP headers
- SRI hashes for all CDN-resourced assets (KaTeX, Mermaid, Highlight.js)
- Updated KaTeX to 0.16.21 (CVE fix)
- Pinned Mermaid to 11.15.0

### Changed
- Deployment target: macOS 15.0
- Image embedding offloaded to background actor
- Debounced `evaluateJavaScript` calls (100ms/150ms)
- Immediate font updates, debounced appearance updates
- Removed appearance debouncing in favor of persistent style sync

## 2026-05-24

### Added
- Modular ContentView with sidebar navigation
- Search functionality in document preview

### Changed
- Complete Swift 6 concurrency safety overhaul
- KVO `drawsBackground` replaced with modern API

## 2026-05-22

### Added
- Security-scoped bookmark system for persistent file access
- MarkdownPreviewState @Observable class

### Changed
- Async/await migration for file loading and drop handling

## 2026-05-20

### Added
- Markdown renderer with GFM, LaTeX (KaTeX), Mermaid diagram support
- Finder Quick Look preview extension
- Code block action overlays (word wrap, copy)
- Dynamic typography panel
- Dark/light theme support
- Sidebar with recent files

### Changed
- WKWebView-based rendering with CSP enforcement
- Native toolbar with Open, Share, Copy, and Text Style controls

## 2026-05-18

### Added
- Initial project scaffold
- XcodeGen project definition (`project.yml`)
- SwiftUI app shell with navigation split view
