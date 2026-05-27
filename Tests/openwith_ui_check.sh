#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
content_view="$ROOT_DIR/App/ContentView.swift"
app_view="$ROOT_DIR/App/PeekMarkApp.swift"
extension_preview="$ROOT_DIR/Extension/PreviewProvider.swift"
loader="$ROOT_DIR/Shared/MarkdownDocumentLoader.swift"

if ! grep -q 'Label("Open File...", systemImage: "doc.badge.plus")' "$content_view"; then
  echo "Open With UI should use native toolbar items for the open file button."
  exit 1
fi

if ! grep -q '\.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)' "$content_view"; then
  echo "Open With UI should hide the window toolbar background."
  exit 1
fi

if ! grep -q 'withSecurityScopedAccess' "$loader"; then
  echo "Markdown loading should expose a shared security-scoped access helper."
  exit 1
fi

if ! grep -q 'startAccessingSecurityScopedResource' "$extension_preview"; then
  echo "Quick Look rendering should keep security-scoped access open through render."
  exit 1
fi

if ! grep -q 'BookmarkManager.resolveBookmark' "$content_view"; then
  echo "Open With rendering should handle security-scoped access."
  exit 1
fi

echo "openwith_ui_check passed"
