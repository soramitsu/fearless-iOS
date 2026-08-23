#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
readonly REPO_ROOT

ruby "$REPO_ROOT/fastlane/spec/fearless_testflight_test.rb"
bash -n "$REPO_ROOT/scripts/fastlane.sh"
plutil -lint "$REPO_ROOT/fastlane/ExportOptions.plist" >/dev/null
rg -F 'auth.fetch(:session_password)' "$REPO_ROOT/fastlane/Fastfile" >/dev/null
rg -F 'apple_id: APP_ID' "$REPO_ROOT/fastlane/Fastfile" >/dev/null
readme_before="$(shasum -a 256 "$REPO_ROOT/fastlane/README.md" | awk '{print $1}')"
FASTLANE_SKIP_UPDATE_CHECK=1 "$REPO_ROOT/scripts/fastlane.sh" lanes >/dev/null
readme_after="$(shasum -a 256 "$REPO_ROOT/fastlane/README.md" | awk '{print $1}')"
[[ "$readme_before" == "$readme_after" ]] || {
  printf '%s\n' "[fastlane-testflight-test] ERROR: Fastlane mutated its tracked runbook" >&2
  exit 1
}

printf '%s\n' "[fastlane-testflight-test] PASS"
