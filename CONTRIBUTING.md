# Contributing to PeekMark

Thanks for your interest! Here's how to help.

## Bug Reports

Open an issue with:
- macOS version, Xcode version
- Steps to reproduce
- Expected vs actual behavior
- Screenshot if visual

## Feature Requests

Open an issue describing what you'd like and why. Be specific about the use case.

## Pull Requests

1. Fork and create a branch from `main`.
2. Run `xcodegen --project .` before opening the project.
3. Ensure all tests pass: `xcodebuild -project PeekMark.xcodeproj -scheme PeekMark test`
4. Run shell checks: `Tests/packaging_scripts_check.sh`
5. Keep changes focused — one logical change per PR.
6. Write a clear commit message and PR description.

## Code Style

- Swift 6 with strict concurrency checking enabled.
- Follow existing patterns — the project uses NSViewRepresentable for WKWebView integration.
- No force-unwraps (`!`) unless absolutely necessary and justified.
- All rendering changes must include/update tests in `Tests/MarkdownRendererTests.swift`.
