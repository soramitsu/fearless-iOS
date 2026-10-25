#!/usr/bin/env bash
set -euo pipefail

readonly REQUIRED_FASTLANE_VERSION="2.238.0"
readonly LOG_PREFIX="[fearless-fastlane]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
readonly REPO_ROOT

fail() {
  printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2
  exit 1
}

if [[ -n "${FASTLANE_BIN:-}" ]]; then
  fastlane_bin="$FASTLANE_BIN"
elif [[ -x /opt/homebrew/bin/fastlane ]]; then
  fastlane_bin=/opt/homebrew/bin/fastlane
elif command -v fastlane >/dev/null 2>&1; then
  fastlane_bin="$(command -v fastlane)"
else
  fail "Fastlane is unavailable. Install Homebrew Fastlane ${REQUIRED_FASTLANE_VERSION}."
fi

[[ -x "$fastlane_bin" ]] || fail "Fastlane is not executable: $fastlane_bin"

version_output="$(FASTLANE_SKIP_UPDATE_CHECK=1 "$fastlane_bin" --version 2>&1)" || {
  printf '%s\n' "$version_output" >&2
  fail "Fastlane could not start"
}
actual_version="$(printf '%s\n' "$version_output" | sed -nE 's/^fastlane ([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' | tail -n 1)"
[[ "$actual_version" == "$REQUIRED_FASTLANE_VERSION" ]] ||
  fail "reviewed Fastlane ${REQUIRED_FASTLANE_VERSION} is required; found ${actual_version:-unknown} at $fastlane_bin"

export FASTLANE_SKIP_UPDATE_CHECK=1
export FASTLANE_HIDE_CHANGELOG=1
export FASTLANE_SKIP_DOCS=1
export SKIP_SLOW_FASTLANE_WARNING=1
cd "$REPO_ROOT"
exec "$fastlane_bin" "$@"
