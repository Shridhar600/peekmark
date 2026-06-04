#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_APP_PATH="$ROOT_DIR/.build/DerivedData/Build/Products/Debug/PeekMark.app"
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

remove_installed_app() {
  if [[ "$INSTALL_PATH" != "/Applications/PeekMark.app" ]]; then
    echo "Refusing to remove unexpected install path: $INSTALL_PATH" >&2
    exit 1
  fi

  if [[ -e "$INSTALL_PATH" && ! -d "$INSTALL_PATH" ]]; then
    echo "Refusing to remove non-directory at $INSTALL_PATH" >&2
    exit 1
  fi

  if [[ -d "$INSTALL_PATH" ]]; then
    rm -rf "$INSTALL_PATH"
  else
    echo "PeekMark is not installed at $INSTALL_PATH"
  fi
}

if pgrep -x "PeekMark" >/dev/null 2>&1; then
  pkill -x "PeekMark"
fi

verify_existing_install_identity "$INSTALL_PATH"
unregister_launch_services "$INSTALL_PATH"
if [[ -d "$DERIVED_DATA_APP_PATH" && -f "$DERIVED_DATA_APP_PATH/Contents/Info.plist" ]]; then
  unregister_launch_services "$DERIVED_DATA_APP_PATH"
else
  echo "Skipped Launch Services unregister for local build at $DERIVED_DATA_APP_PATH because the bundle is missing or incomplete."
fi
remove_installed_app

qlmanage -r cache
qlmanage -r

echo "PeekMark uninstall complete"
