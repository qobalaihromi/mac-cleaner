#!/usr/bin/env bash
set -euo pipefail

BIN_PATH="${HOME}/.local/bin/mac-cleaner"
if [[ -f "${BIN_PATH}" ]]; then
  rm -f "${BIN_PATH}"
  echo "Removed: ${BIN_PATH}"
else
  echo "Not installed: ${BIN_PATH}"
fi
