#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Mac Cleaner.app"
APP_DIR="${HOME}/Applications/${APP_NAME}"
EXEC_NAME="MacCleanerGUI"

mkdir -p "${HOME}/Applications"
cd "${ROOT_DIR}"

swift build -c release --product ${EXEC_NAME}

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${ROOT_DIR}/.build/release/${EXEC_NAME}" "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${EXEC_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.local.maccleaner.gui</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Mac Cleaner</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "Installed GUI app: ${APP_DIR}"
echo "Open with: open \"${APP_DIR}\""
