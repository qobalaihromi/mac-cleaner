#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${HOME}/.local/bin"
OUT_BIN="${BIN_DIR}/mac-cleaner"

mkdir -p "${BIN_DIR}"
cd "${ROOT_DIR}"

swift build -c release
cp "${ROOT_DIR}/.build/release/mac-cleaner" "${OUT_BIN}"
chmod +x "${OUT_BIN}"

echo "Installed: ${OUT_BIN}"
echo
if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
  echo "Add this to your shell profile (~/.zshrc):"
  echo "export PATH=\"${BIN_DIR}:\$PATH\""
fi

echo "Try: mac-cleaner help"
