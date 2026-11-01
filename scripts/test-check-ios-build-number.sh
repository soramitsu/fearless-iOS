#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly CHECK="$REPO_ROOT/scripts/check-ios-build-number.sh"
readonly FIXTURES="$(mktemp -d "${TMPDIR:-/tmp}/fearless-build-number-tests.XXXXXX")"
readonly PINNED_FILES=(
  fearless.xcodeproj/project.pbxproj
  Jenkinsfile
  fastlane/.env.example
  fastlane/README.md
  scripts/ci/build-audited-ios-release-archive.sh
  scripts/audit-testflight-upgrade-usability-gate.py
  scripts/capture-testflight-startup.py
)

trap 'rm -rf "$FIXTURES"' EXIT

pass_count=0
fail_count=0
case_root=""

prepare_case() {
  case_root="$FIXTURES/$1"
  local file
  for file in "${PINNED_FILES[@]}"; do
    mkdir -p "$case_root/$(dirname "$file")"
    cp "$REPO_ROOT/$file" "$case_root/$file"
  done
}

# Replaces one exact line in the case copy and fails if it was not present.
replace_line() {
  local file="$1"
  local old="$2"
  local new="$3"

  python3 - "$case_root/$file" "$old" "$new" <<'PYTHON'
import sys
from pathlib import Path
path, old, new = sys.argv[1:]
lines = Path(path).read_text().split('\n')
matches = [index for index, line in enumerate(lines) if line == old]
assert len(matches) == 1, f'{path}: expected exactly one line {old!r}, found {len(matches)}'
lines[matches[0]] = new
Path(path).write_text('\n'.join(lines))
PYTHON
}

release_build="$(bash "$CHECK" "$REPO_ROOT" | sed -nE 's/.*Release 4\.2\.0 \(([0-9.]+)\).*/\1/p')"
[[ -n "$release_build" ]] || {
  printf '[ios-build-number-test] the repository itself does not pass the check\n' >&2
  exit 1
}

set_all_pins() {
  local build="$1"
  replace_line fearless.xcodeproj/project.pbxproj \
    "				CURRENT_PROJECT_VERSION = $release_build;" \
    "				CURRENT_PROJECT_VERSION = $build;"
  replace_line Jenkinsfile \
    "        IOS_EXPECTED_BUILD_NUMBER=$release_build \\" \
    "        IOS_EXPECTED_BUILD_NUMBER=$build \\"
  replace_line fastlane/.env.example "TESTFLIGHT_BUILD=$release_build" "TESTFLIGHT_BUILD=$build"
  python3 - "$case_root/fastlane/README.md" "$release_build" "$build" <<'PYTHON'
import sys
from pathlib import Path
path, old, new = sys.argv[1:]
source = Path(path).read_text()
assert source.count(f'  build:{old}\n') == 2, 'README must document both lanes'
Path(path).write_text(source.replace(f'  build:{old}\n', f'  build:{new}\n'))
PYTHON
  replace_line scripts/ci/build-audited-ios-release-archive.sh \
    "readonly EXPECTED_BUILD=\"$release_build\"" "readonly EXPECTED_BUILD=\"$build\""
  replace_line scripts/audit-testflight-upgrade-usability-gate.py \
    "EXPECTED_BUILD = \"$release_build\"" "EXPECTED_BUILD = \"$build\""
  replace_line scripts/capture-testflight-startup.py \
    "SAFE_UPGRADE_BUILD_NUMBER = \"$release_build\"" "SAFE_UPGRADE_BUILD_NUMBER = \"$build\""
}

run_pass() {
  local label="$1"

  if bash "$CHECK" "$case_root" >/dev/null 2>&1; then
    pass_count=$((pass_count + 1))
  else
    printf '[ios-build-number-test] expected pass: %s\n' "$label" >&2
    bash "$CHECK" "$case_root" >&2 || true
    exit 1
  fi
}

run_reject() {
  local label="$1"
  local reason="$2"
  local output

  if output="$(bash "$CHECK" "$case_root" 2>&1)"; then
    printf '[ios-build-number-test] expected rejection: %s\n' "$label" >&2
    exit 1
  fi
  [[ "$output" == *"$reason"* ]] || {
    printf '[ios-build-number-test] %s was rejected for the wrong reason: %s\n' "$label" "$output" >&2
    exit 1
  }
  fail_count=$((fail_count + 1))
}

prepare_case canonical
run_pass canonical

# App Store Connect compares numeric components, not text: 2026.11.10 follows
# the latest consumed build 2026.11.2 and 2026.9.10 precedes it, although text
# order puts the 2026.9.x builds last.
prepare_case numeric-successor
set_all_pins 2026.11.10
run_pass numeric-successor

prepare_case text-successor-only
set_all_pins 2026.9.10
run_reject text-successor-only "2026.9.10 is not greater than latest consumed build 2026.11.2"

prepare_case reused-latest-build
set_all_pins 2026.11.2
run_reject reused-latest-build "2026.11.2 is not greater than latest consumed build 2026.11.2"

prepare_case reused-iroha-build
set_all_pins 2026.8.34
run_reject reused-iroha-build "2026.8.34 is not greater than latest consumed build 2026.11.2"

prepare_case release-listed-as-predecessor
replace_line scripts/audit-testflight-upgrade-usability-gate.py \
  '    "2026.9.6",' "    \"2026.9.6\",
    \"$release_build\","
run_reject release-listed-as-predecessor "is not greater than latest consumed build $release_build"

prepare_case project-drift
replace_line fearless.xcodeproj/project.pbxproj \
  "				CURRENT_PROJECT_VERSION = $release_build;" \
  "				CURRENT_PROJECT_VERSION = 2026.11.4;"
run_reject project-drift "pins $release_build, but the Release target builds 2026.11.4"

prepare_case jenkins-drift
replace_line Jenkinsfile \
  "        IOS_EXPECTED_BUILD_NUMBER=$release_build \\" \
  "        IOS_EXPECTED_BUILD_NUMBER=2026.8.34 \\"
run_reject jenkins-drift "Jenkinsfile pins 2026.8.34"

prepare_case fastlane-env-drift
replace_line fastlane/.env.example "TESTFLIGHT_BUILD=$release_build" "TESTFLIGHT_BUILD=2026.9.6"
run_reject fastlane-env-drift "fastlane/.env.example pins 2026.9.6"

prepare_case fastlane-version-drift
replace_line fastlane/.env.example "TESTFLIGHT_VERSION=4.2.0" "TESTFLIGHT_VERSION=4.1.0"
run_reject fastlane-version-drift "TESTFLIGHT_VERSION must be 4.2.0"

prepare_case readme-drift
python3 - "$case_root/fastlane/README.md" "$release_build" <<'PYTHON'
import sys
from pathlib import Path
path, build = sys.argv[1:]
source = Path(path).read_text()
marker = f'ios publish_archive \\\n  version:4.2.0 \\\n  build:{build}\n'
assert source.count(marker) == 1
Path(path).write_text(source.replace(marker, marker.replace(build, '2026.8.34')))
PYTHON
run_reject readme-drift "fastlane/README.md publish_archive pins 2026.8.34"

prepare_case archive-drift
replace_line scripts/ci/build-audited-ios-release-archive.sh \
  "readonly EXPECTED_BUILD=\"$release_build\"" 'readonly EXPECTED_BUILD="2026.9.6"'
run_reject archive-drift "build-audited-ios-release-archive.sh pins 2026.9.6"

prepare_case duplicate-archive-pin
replace_line scripts/ci/build-audited-ios-release-archive.sh \
  "readonly EXPECTED_BUILD=\"$release_build\"" "readonly EXPECTED_BUILD=\"$release_build\"
readonly EXPECTED_BUILD=\"$release_build\""
run_reject duplicate-archive-pin "must pin exactly one build, found 2"

prepare_case usability-gate-drift
replace_line scripts/audit-testflight-upgrade-usability-gate.py \
  "EXPECTED_BUILD = \"$release_build\"" 'EXPECTED_BUILD = "2026.8.34"'
run_reject usability-gate-drift "upgrade-usability-gate.py pins 2026.8.34"

prepare_case capture-drift
replace_line scripts/capture-testflight-startup.py \
  "SAFE_UPGRADE_BUILD_NUMBER = \"$release_build\"" 'SAFE_UPGRADE_BUILD_NUMBER = "2026.9.6"'
run_reject capture-drift "capture-testflight-startup.py pins 2026.9.6"

prepare_case capture-not-allowlisted
replace_line scripts/capture-testflight-startup.py "    SAFE_UPGRADE_BUILD_NUMBER," ""
run_reject capture-not-allowlisted "does not allowlist SAFE_UPGRADE_BUILD_NUMBER"

prepare_case wrong-marketing-version
replace_line fearless.xcodeproj/project.pbxproj \
  "				MARKETING_VERSION = 4.2.0;" "				MARKETING_VERSION = 4.1.9;"
run_reject wrong-marketing-version "MARKETING_VERSION must be 4.2.0"

prepare_case non-canonical-build
set_all_pins 2026.10.1-rc
run_reject non-canonical-build "is not a canonical CFBundleVersion"

prepare_case missing-tool
rm "$case_root/scripts/capture-testflight-startup.py"
run_reject missing-tool "capture-testflight-startup.py is missing"

printf '%s\n' \
  "[ios-build-number-test] PASS: $pass_count positive and $fail_count negative/adversarial cases"
