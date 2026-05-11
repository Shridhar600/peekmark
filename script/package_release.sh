#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug/PeekMark.app"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/PeekMark-debug.zip"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

verify_clean_entitlements() {
  local target="$1"
  local entitlements
  entitlements="$(codesign -d --entitlements - "$target" 2>/dev/null)"
  if echo "$entitlements" | grep -E "com.apple.security.network.client|temporary-exception.files.absolute-path" >/dev/null; then
    echo "Refusing to package: forbidden entitlement found in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
}

xcodegen --project "$ROOT_DIR"

xcodebuild \
  -project "$ROOT_DIR/PeekMark.xcodeproj" \
  -scheme "PeekMark" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  clean build

verify_clean_entitlements "$APP_PATH"
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
