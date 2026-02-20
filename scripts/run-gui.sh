#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

swift build -c release --product MacCleanerGUI
exec "${ROOT_DIR}/.build/release/MacCleanerGUI"
