#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData"
CONFIGURATION="${CONFIGURATION:-Release}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/PeekMark.app"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/PeekMark-$CONFIGURATION.zip"



verify_clean_entitlements() {
  local target="$1"
  local allow_network="${2:-false}"
  local require_network="${3:-false}"
  local entitlements
  entitlements="$(codesign -d --entitlements - "$target" 2>/dev/null)"
  if [[ "$allow_network" != "true" ]] && echo "$entitlements" | grep "com.apple.security.network.client" >/dev/null; then
    echo "Refusing to package: forbidden entitlement found in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
  if [[ "$require_network" == "true" ]] && ! echo "$entitlements" | grep -q "com.apple.security.network.client"; then
    echo "Refusing to package: missing required network client entitlement in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
  if echo "$entitlements" | grep "temporary-exception.files.absolute-path" >/dev/null; then
    echo "Refusing to package: forbidden entitlement found in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
}

xcodegen --project "$ROOT_DIR"

xcodebuild \
  -project "$ROOT_DIR/PeekMark.xcodeproj" \
  -scheme "PeekMark" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  clean build

verify_clean_entitlements "$APP_PATH" true true
verify_clean_entitlements "$APP_PATH/Contents/PlugIns/PeekMarkQuickLookExtension.appex"

if [[ ! -f "$APP_PATH/Contents/Resources/Assets.car" ]]; then
  echo "Refusing to package: missing app icon asset catalog" >&2
  exit 1
fi

plutil -extract CFBundleIconName raw "$APP_PATH/Contents/Info.plist" >/dev/null
plutil -extract CFBundleIconFile raw "$APP_PATH/Contents/Info.plist" >/dev/null

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Created $ZIP_PATH"
