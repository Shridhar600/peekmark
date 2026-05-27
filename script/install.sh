#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData"
CONFIGURATION="${CONFIGURATION:-Debug}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/PeekMark.app"
INSTALL_PATH="/Applications/PeekMark.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

bundle_identifier() {
  local target="$1"
  plutil -extract CFBundleIdentifier raw "$target/Contents/Info.plist" 2>/dev/null || true
}

verify_existing_install_identity() {
  local target="$1"

  if [[ ! -d "$target" ]]; then
    return
  fi

  local identifier
  identifier="$(bundle_identifier "$target")"
  if [[ "$identifier" != "app.peekmark.mac" ]]; then
    echo "Refusing to modify $target because its bundle identifier is '$identifier', not app.peekmark.mac" >&2
    exit 1
  fi
}

unregister_launch_services() {
  local target="$1"
  local output exit_status

  if [[ ! -x "$LSREGISTER" ]]; then
    echo "Launch Services unregister tool is not executable: $LSREGISTER" >&2
    exit 1
  fi

  if [[ -d "$target" ]]; then
    if output="$("$LSREGISTER" -u "$target" 2>&1)"; then
      echo "Unregistered Launch Services entry for $target."
    else
      exit_status=$?
      echo "Warning: lsregister -u could not unregister $target (status $exit_status): $output" >&2
      output="${output//$'\n'/ }"
      echo "Launch Services unregister for $target returned status $exit_status and was treated as non-fatal."
    fi
  else
    echo "Skipped Launch Services unregister for $target because the bundle is not present."
  fi
}

remove_existing_install() {
  if [[ "$INSTALL_PATH" != "/Applications/PeekMark.app" ]]; then
    echo "Refusing to remove unexpected install path: $INSTALL_PATH" >&2
    exit 1
  fi

  if [[ -e "$INSTALL_PATH" && ! -d "$INSTALL_PATH" ]]; then
    echo "Refusing to replace non-directory at $INSTALL_PATH" >&2
    exit 1
  fi

  if [[ -d "$INSTALL_PATH" ]]; then
    rm -rf "$INSTALL_PATH"
    echo "Removed existing /Applications/PeekMark.app before reinstall."
  fi
}

verify_clean_entitlements() {
  local target="$1"
  local allow_network="${2:-false}"
  local require_network="${3:-false}"
  local entitlements
  entitlements="$(codesign -d --entitlements - "$target" 2>/dev/null)"
  if ! echo "$entitlements" | grep -q "com.apple.security.app-sandbox"; then
    echo "Refusing to install: missing sandbox entitlement in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
  if ! echo "$entitlements" | grep -q "com.apple.security.files.user-selected.read-only"; then
    echo "Refusing to install: missing read-only file entitlement in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
  if [[ "$allow_network" != "true" ]] && echo "$entitlements" | grep "com.apple.security.network.client" >/dev/null; then
    echo "Refusing to install: forbidden entitlement found in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
  if [[ "$require_network" == "true" ]] && ! echo "$entitlements" | grep -q "com.apple.security.network.client"; then
    echo "Refusing to install: missing required network client entitlement in $target" >&2
    echo "$entitlements" >&2
    exit 1
  fi
  if echo "$entitlements" | grep "temporary-exception.files.absolute-path" >/dev/null; then
    echo "Refusing to install: forbidden entitlement found in $target" >&2
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
  clean build

verify_clean_entitlements "$APP_PATH" true true
verify_clean_entitlements "$APP_PATH/Contents/PlugIns/PeekMarkQuickLookExtension.appex"

if [[ "$APP_PATH" != "$ROOT_DIR/.build/DerivedData/Build/Products/Debug/PeekMark.app" ]]; then
  echo "Refusing to install from unexpected build artifact path: $APP_PATH" >&2
  exit 1
fi

if pgrep -x "PeekMark" >/dev/null 2>&1; then
  pkill -x "PeekMark"
fi

verify_existing_install_identity "$INSTALL_PATH"
unregister_launch_services "$INSTALL_PATH"
unregister_launch_services "$APP_PATH"
remove_existing_install
ditto "$APP_PATH" "$INSTALL_PATH"

open -na "$INSTALL_PATH"

qlmanage -r cache
qlmanage -r

"$ROOT_DIR/script/verify_install.sh"
