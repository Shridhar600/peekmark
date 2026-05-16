#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
content_view="$ROOT_DIR/App/ContentView.swift"
app_view="$ROOT_DIR/App/PeekMarkApp.swift"
extension_preview="$ROOT_DIR/Extension/PreviewProvider.swift"
loader="$ROOT_DIR/Shared/MarkdownDocumentLoader.swift"

if grep -q 'AppearanceToolbarPicker' "$content_view"; then
  echo "Open With UI should use native toolbar menu controls, not a custom appearance picker."
  exit 1
fi

if grep -q 'OpenFileButton' "$content_view"; then
  echo "Open With UI should use native toolbar buttons, not a custom open-file capsule."
  exit 1
fi

if grep -q '\.buttonStyle(.plain)' "$content_view"; then
  echo "Toolbar controls should use native toolbar styling, not plain custom button styling."
  exit 1
fi

if grep -q '\.onTapGesture' "$content_view"; then
  echo "Toolbar controls should not combine Button actions with duplicate onTapGesture handlers."
  exit 1
fi

if ! grep -q 'Label("Open Markdown", systemImage: "doc.badge.plus")' "$content_view"; then
  echo "Open With UI should keep a native toolbar Open Markdown button."
  exit 1
fi

if ! grep -q 'private struct AppearanceToolbarMenu' "$content_view"; then
  echo "Open With UI should keep appearance selection in a native toolbar menu."
  exit 1
fi

if ! grep -q 'Menu {' "$content_view"; then
  echo "Open With UI should use a native Menu for appearance selection."
  exit 1
fi

if ! grep -q '\.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)' "$content_view"; then
  echo "Open With UI should hide the window toolbar background so controls blend into the window."
  exit 1
fi

if ! grep -q '\.toolbar(removing: .title)' "$content_view"; then
  echo "Open With UI should remove the visible title while preserving native window chrome."
  exit 1
fi

if ! grep -q 'Task.detached(priority: .userInitiated)' "$content_view"; then
  echo "Open With file rendering should run off the main actor to keep the window responsive."
  exit 1
fi

if ! grep -q 'renderGeneration' "$content_view"; then
  echo "Open With async rendering should guard against stale render results."
  exit 1
fi

if ! grep -q 'reloadForAppearanceChange' "$content_view"; then
  echo "Appearance changes should invalidate stale async renders."
  exit 1
fi

if ! grep -q '\.windowToolbarStyle(.unifiedCompact(showsTitle: false))' "$app_view"; then
  echo "Open With window should use unified compact native toolbar chrome."
  exit 1
fi

if ! grep -q 'withSecurityScopedAccess' "$loader"; then
  echo "Markdown loading should expose a shared security-scoped access helper."
  exit 1
fi

if ! grep -q 'withSecurityScopedAccess(to: request.fileURL)' "$extension_preview"; then
  echo "Quick Look rendering should keep security-scoped access open through render."
  exit 1
fi

if ! grep -q 'withSecurityScopedAccess(to: url)' "$content_view"; then
  echo "Open With rendering should keep security-scoped access open through render."
  exit 1
fi
