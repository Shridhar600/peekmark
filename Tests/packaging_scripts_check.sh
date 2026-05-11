#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

required_scripts=(
  "$ROOT_DIR/script/install.sh"
  "$ROOT_DIR/script/uninstall.sh"
  "$ROOT_DIR/script/verify_install.sh"
  "$ROOT_DIR/script/package_release.sh"
)

for script in "${required_scripts[@]}"; do
  if [[ ! -x "$script" ]]; then
    echo "Missing executable script: $script" >&2
    exit 1
  fi
  zsh -n "$script"
done

grep -q "ditto" "$ROOT_DIR/script/install.sh"
grep -q "/Applications/PeekMark.app" "$ROOT_DIR/script/install.sh"
grep -q ".build/DerivedData/Build/Products/Debug/PeekMark.app" "$ROOT_DIR/script/install.sh"
grep -q "clean build" "$ROOT_DIR/script/install.sh"
grep -q "qlmanage -r cache" "$ROOT_DIR/script/install.sh"
grep -q "lsregister" "$ROOT_DIR/script/install.sh"
grep -q "lsregister -u" "$ROOT_DIR/script/install.sh"
grep -q "Unregistered Launch Services entry" "$ROOT_DIR/script/install.sh"
grep -q "Skipped Launch Services unregister" "$ROOT_DIR/script/install.sh"
grep -q "treated as non-fatal" "$ROOT_DIR/script/install.sh"
grep -q "Refusing to modify" "$ROOT_DIR/script/install.sh"
grep -q "missing sandbox entitlement" "$ROOT_DIR/script/install.sh"
grep -q "missing read-only file entitlement" "$ROOT_DIR/script/install.sh"
grep -q "missing required network client entitlement" "$ROOT_DIR/script/install.sh"
grep -q "docs/system-changes.md" "$ROOT_DIR/script/install.sh"
grep -q "codesign" "$ROOT_DIR/script/verify_install.sh"
grep -q "Assets.car" "$ROOT_DIR/script/verify_install.sh"
grep -q "Missing required network client entitlement" "$ROOT_DIR/script/verify_install.sh"
grep -q "com.apple.security.network.client" "$ROOT_DIR/App/PeekMark.entitlements"
grep -q "Installed app must be a real bundle, not a symlink" "$ROOT_DIR/script/verify_install.sh"
grep -q "Missing required sandbox entitlement" "$ROOT_DIR/script/verify_install.sh"
grep -q "Missing required read-only file entitlement" "$ROOT_DIR/script/verify_install.sh"
grep -q "DerivedData app unexpectedly resolves under /Applications" "$ROOT_DIR/script/verify_install.sh"
grep -q "Found local build artifact only" "$ROOT_DIR/script/verify_install.sh"
grep -q "ditto -c -k" "$ROOT_DIR/script/package_release.sh"
grep -q "clean build" "$ROOT_DIR/script/package_release.sh"
grep -q "Assets.car" "$ROOT_DIR/script/package_release.sh"
grep -q "missing required network client entitlement" "$ROOT_DIR/script/package_release.sh"
grep -q 'verify_clean_entitlements "$APP_PATH" true true' "$ROOT_DIR/script/package_release.sh"
grep -q "/Applications/PeekMark.app" "$ROOT_DIR/script/uninstall.sh"
grep -q ".build/DerivedData/Build/Products/Debug/PeekMark.app" "$ROOT_DIR/script/uninstall.sh"
grep -q "lsregister" "$ROOT_DIR/script/uninstall.sh"
grep -q "lsregister -u" "$ROOT_DIR/script/uninstall.sh"
grep -q "Unregistered Launch Services entry" "$ROOT_DIR/script/uninstall.sh"
grep -q "Skipped Launch Services unregister" "$ROOT_DIR/script/uninstall.sh"
grep -q "treated as non-fatal" "$ROOT_DIR/script/uninstall.sh"
grep -q "Refusing to modify" "$ROOT_DIR/script/uninstall.sh"
grep -q "docs/system-changes.md" "$ROOT_DIR/script/uninstall.sh"
grep -q "MarkdownPreviewView" "$ROOT_DIR/App/ContentView.swift"

if grep "whatMD.app" "$ROOT_DIR/script/install.sh" "$ROOT_DIR/script/uninstall.sh" "$ROOT_DIR/script/package_release.sh" >/dev/null; then
  echo "Install, uninstall, and package scripts must not operate on stale whatMD.app" >&2
  exit 1
fi

echo "packaging scripts check passed"
