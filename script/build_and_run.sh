#!/bin/zsh

set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData"
CONFIGURATION="${CONFIGURATION:-Debug}"
APP_NAME="PeekMark.app"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME"
PROCESS_NAME="PeekMark"



if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
  pkill -x "$PROCESS_NAME"
fi

xcodegen --project "$ROOT_DIR"

xcodebuild \
  -project "$ROOT_DIR/PeekMark.xcodeproj" \
  -scheme "PeekMark" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

case "$MODE" in
  run|--run)
    /usr/bin/open -n "$APP_PATH"
    ;;
  verify|--verify)
    /usr/bin/open -n "$APP_PATH"
    sleep 1
    pgrep -x "$PROCESS_NAME" >/dev/null
    ;;
  logs|--logs)
    /usr/bin/open -n "$APP_PATH"
    /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
    ;;
  debug|--debug)
    lldb -- "$APP_PATH/Contents/MacOS/$PROCESS_NAME"
    ;;
  *)
    echo "usage: $0 [run|verify|logs|debug]" >&2
    exit 2
    ;;
esac
