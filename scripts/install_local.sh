#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/Jekyll Desk/Jekyll Desk.xcodeproj"
SCHEME="${SCHEME:-Jekyll Desk}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="${APP_NAME:-Jekyll Desk.app}"
PROCESS_NAME="${PROCESS_NAME:-Jekyll Desk}"
INSTALL_PATH="${INSTALL_PATH:-/Applications/$APP_NAME}"
OPEN_AFTER_INSTALL="${OPEN_AFTER_INSTALL:-0}"
DERIVED_DATA_PATH="$(mktemp -d "${TMPDIR:-/tmp}/jekyll-desk-build.XXXXXX")"
BUILD_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"

cleanup() {
  rm -rf "$DERIVED_DATA_PATH"
}

trap cleanup EXIT

echo "Using derived data at:"
echo "  $DERIVED_DATA_PATH"

echo "Building $SCHEME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$BUILD_APP_PATH" ]]; then
  echo "Build succeeded but app was not found at:"
  echo "  $BUILD_APP_PATH"
  exit 1
fi

echo "Stopping running app if needed..."
pkill -x "$PROCESS_NAME" || true

echo "Installing to:"
echo "  $INSTALL_PATH"
ditto "$BUILD_APP_PATH" "$INSTALL_PATH"

echo "Installed:"
echo "  $INSTALL_PATH"

if [[ "$OPEN_AFTER_INSTALL" == "1" ]]; then
  echo "Opening app..."
  open "$INSTALL_PATH"
fi
