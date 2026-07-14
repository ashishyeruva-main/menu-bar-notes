#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MenuBarNotes"
BUILD_CONFIG="${1:-release}"

BIN_PATH=".build/${BUILD_CONFIG}/${APP_NAME}"
APP_DIR="../${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"

echo "==> Building (${BUILD_CONFIG})"
swift build -c "${BUILD_CONFIG}"

echo "==> Assembling bundle"
rm -rf "${APP_DIR}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"

cp "${BIN_PATH}" "${CONTENTS}/MacOS/${APP_NAME}"
cp Resources/Info.plist "${CONTENTS}/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "${CONTENTS}/Resources/"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Done: ${APP_DIR}"
echo "Run with: open ${APP_DIR}"
