# Changelog

All notable changes to PeekMark will be documented in this file.

## Unreleased

### Added
- HTML sanitizer for generated content (footnotes, remote URL stripping)
- CSS cache by style parameters for reduced regeneration
- `nonisolated(unsafe)` annotations for QuickLook extension Sendable conformance
- `@MainActor` isolation on `MarkdownAppearance.resolved`
- `OSAllocatedUnfairLock` for thread-safe continuation completion
- Graceful error alerts when a recent or pinned folder source can no longer be opened (moved or deleted), instead of a silent no-op
- Graceful feedback when a non-Markdown file or folder is dropped on the reading area or a collection
- Recent Documents list now holds up to 10 items (was 5)

### Fixed
- Search highlighting JS: `queryLower` → `query.toLowerCase()` undefined variable
- Swift 6 concurrency warnings: Sendable closures, actor isolation, deprecated API usage
- Footnote HTML now sanitized before rendering
- Mermaid `securityLevel` changed to `strict` (was `'loose'`)
- QuickLook extension compile warnings for NSAppearance cross-thread capture
- `evaluateJavaScript` callback/deprecation warnings
- Document-info popover no longer renders Liquid Glass on top of the popover's own glass
- Thread-safe CSS cache (`OSAllocatedUnfairLock`) — fixes a data race under rapid document/style switches
- Pinned files now re-mint stale security-scoped bookmarks, so pinned access no longer silently decays over time / OS updates
- Recent documents now carry their own security-scoped bookmark and reliably reopen after relaunch (previously they could silently break)
- Adding a recent to a collection now succeeds (the file's security scope is held while the pin is created)
- Pinned-folder rows now align with file rows in the sidebar

### Changed
- CSP tightened while retaining the CDN allowlist required by the current renderer
- `withCheckedContinuation` timeout pattern uses `OSAllocatedUnfairLock`
- Default packaged build configuration: `Release`
- Rewrote `openwith_ui_check.sh` for current UI patterns
- Cleaned install/uninstall scripts (removed internal logging references)
- Typography/appearance changes update the preview incrementally instead of rebuilding the full themed HTML on the main thread — smoother font-size slider on large documents
- Security scope is released immediately after the file read rather than held across rendering
- Vendor scripts (Highlight.js / KaTeX / Mermaid) are escaped once at load instead of on every render

### Removed
- Internal docs from tracking (`PeekMark.xcodeproj/` gitignored)
- Internal development docs and audit files
- Stale grep patterns from packaging checks
- Placeholder Homebrew cask until a real release artifact and checksum exist

## 2026-05-27

### Added
- MIT LICENSE file

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
