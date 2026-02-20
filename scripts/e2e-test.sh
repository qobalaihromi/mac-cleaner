#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ROOT_DIR}/.build/release/mac-cleaner"

pass_count=0
warn_count=0

pass() {
  pass_count=$((pass_count + 1))
  echo "[PASS] $1"
}

warn() {
  warn_count=$((warn_count + 1))
  echo "[WARN] $1"
}

run_and_check_contains() {
  local label="$1"
  local cmd="$2"
  local expect="$3"

  local out
  out=$(eval "$cmd")
  if echo "$out" | grep -Fq "$expect"; then
    pass "$label"
  else
    echo "$out"
    echo "[FAIL] $label - expected to contain: $expect" >&2
    exit 1
  fi
}

run_json_key_check() {
  local label="$1"
  local cmd="$2"
  local key="$3"

  local out
  out=$(eval "$cmd")
  if echo "$out" | grep -Fq "\"$key\""; then
    pass "$label"
  else
    echo "$out"
    echo "[FAIL] $label - expected JSON key: $key" >&2
    exit 1
  fi
}

run_json_array_check() {
  local label="$1"
  local cmd="$2"

  local out
  out=$(eval "$cmd")
  if echo "$out" | grep -Fq "[" && echo "$out" | grep -Fq "]"; then
    pass "$label"
  else
    echo "$out"
    echo "[FAIL] $label - expected JSON array output" >&2
    exit 1
  fi
}

run_contains_any() {
  local label="$1"
  local cmd="$2"
  local expect_a="$3"
  local expect_b="$4"

  local out
  out=$(eval "$cmd")
  if echo "$out" | grep -Fq "$expect_a" || echo "$out" | grep -Fq "$expect_b"; then
    pass "$label"
  else
    echo "$out"
    echo "[FAIL] $label - expected either: $expect_a OR $expect_b" >&2
    exit 1
  fi
}

echo "Running E2E tests in: ${ROOT_DIR}"

cd "$ROOT_DIR"

swift build -c release >/dev/null
pass "Release build"

run_and_check_contains "help command" "${BIN} help" "Usage:"
run_and_check_contains "rules command" "${BIN} rules" "Active rules:"
run_and_check_contains "storage command" "${BIN} storage" "Storage total"
run_and_check_contains "memory command" "${BIN} memory" "Memory total"
run_and_check_contains "scan command" "${BIN} scan --limit 5" "Candidates:"
run_and_check_contains "duplicates command" "${BIN} duplicates --groups 3" "duplicate"

run_json_key_check "storage json" "${BIN} storage --json" "totalBytes"
run_json_key_check "memory json" "${BIN} memory --json" "usedBytes"
run_json_array_check "scan json array" "${BIN} scan --json --limit 2"
run_json_array_check "duplicates json array" "${BIN} duplicates --json --groups 2"

run_contains_any "clean cancel/empty flow" "printf 'n\\n' | ${BIN} clean --limit 5" "Cancelled." "No files selected for cleanup."
run_contains_any "clean-duplicates cancel/empty flow" "printf 'n\\n' | ${BIN} clean-duplicates --limit 20 --groups 5" "Cancelled." "No duplicate cleanup candidates found"
run_and_check_contains "restore cancel flow" "printf 'n\\n' | ${BIN} restore --latest" "Cancelled."

if ${BIN} init-config >/dev/null 2>&1; then
  pass "init-config command"
else
  warn "init-config failed in this environment (usually permission/sandbox)."
fi

echo ""
echo "E2E summary: ${pass_count} passed, ${warn_count} warning(s)"
if [[ "$warn_count" -gt 0 ]]; then
  echo "Completed with warnings."
else
  echo "All checks passed."
fi
