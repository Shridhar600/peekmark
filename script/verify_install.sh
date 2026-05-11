#!/bin/zsh

set -euo pipefail

APP_PATH="/Applications/PeekMark.app"
EXT_PATH="$APP_PATH/Contents/PlugIns/PeekMarkQuickLookExtension.appex"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_APP_PATH="$ROOT_DIR/.build/DerivedData/Build/Products/Debug/PeekMark.app"

if [[ "$APP_PATH" != "/Applications/PeekMark.app" ]]; then
  echo "Verification target must be /Applications/PeekMark.app, got: $APP_PATH" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing installed app: $APP_PATH" >&2
  exit 1
fi

if [[ -L "$APP_PATH" ]]; then
  echo "Installed app must be a real bundle, not a symlink: $APP_PATH" >&2
  exit 1
fi

if [[ ! -d "$EXT_PATH" ]]; then
  echo "Missing installed Quick Look extension: $EXT_PATH" >&2
  exit 1
fi

if [[ ! -f "$APP_PATH/Contents/Resources/Assets.car" ]]; then
  echo "Missing app icon asset catalog in installed app" >&2
  exit 1
fi

plutil -extract CFBundleIconName raw "$APP_PATH/Contents/Info.plist" >/dev/null
plutil -extract CFBundleIconFile raw "$APP_PATH/Contents/Info.plist" >/dev/null
plutil -extract CFBundleIdentifier raw "$APP_PATH/Contents/Info.plist" | grep -q "app.peekmark.mac"
plutil -extract CFBundleIdentifier raw "$EXT_PATH/Contents/Info.plist" | grep -q "app.peekmark.mac.quicklook"

check_entitlements() {
  local target="$1"
  local allow_network="${2:-false}"
  local entitlements
  entitlements="$(codesign -d --entitlements - "$target" 2>/dev/null)"
  if ! echo "$entitlements" | grep -q "com.apple.security.app-sandbox"; then
    echo "Missing required sandbox entitlement in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
  if ! echo "$entitlements" | grep -q "com.apple.security.files.user-selected.read-only"; then
    echo "Missing required read-only file entitlement in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
  if [[ "$allow_network" == "true" ]]; then
    if ! echo "$entitlements" | grep -q "com.apple.security.network.client"; then
      echo "Missing required network client entitlement in $target" >&2
      echo "$entitlements" >&2
      exit 1
    fi
  elif echo "$entitlements" | grep "com.apple.security.network.client" >/dev/null; then
    echo "Forbidden entitlement found in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
  if echo "$entitlements" | grep "temporary-exception.files.absolute-path" >/dev/null; then
    echo "Forbidden entitlement found in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
}

check_entitlements "$APP_PATH" true
check_entitlements "$EXT_PATH"

if [[ -d "$DERIVED_DATA_APP_PATH" ]]; then
  if [[ "$DERIVED_DATA_APP_PATH" == /Applications/* ]]; then
    echo "DerivedData app unexpectedly resolves under /Applications: $DERIVED_DATA_APP_PATH" >&2
    exit 1
  fi
  echo "Found local build artifact only: $DERIVED_DATA_APP_PATH"
fi

if [[ -d "/Applications/whatMD.app" ]]; then
  echo "Stale /Applications/whatMD.app still exists" >&2
  exit 1
fi

echo "PeekMark install verification passed"
