#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"

fail() {
  echo "[check-modern-tooling-contracts] $1" >&2
  exit 1
}

ensure_file() {
  local file="$1"

  [[ -f "$file" ]] || fail "Missing file: $file"
}

ensure_path_absent() {
  local path="$1"

  [[ ! -e "$ROOT/$path" ]] || fail "Removed legacy artifact is present again: $path"
}

ensure_pattern_absent() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  ensure_file "$file"
  if /usr/bin/grep -Fq -- "$pattern" "$file"; then
    fail "$label in ${file#$ROOT/}: $pattern"
  fi
}

ensure_pattern_present() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  ensure_file "$file"
  if ! /usr/bin/grep -Fq -- "$pattern" "$file"; then
    fail "$label missing from ${file#$ROOT/}: $pattern"
  fi
}

ensure_extended_pattern_absent() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  [[ -e "$path" ]] || return 0

  if [[ -d "$path" ]]; then
    if /usr/bin/grep -R -E -n "$pattern" "$path" >/dev/null; then
      fail "$label under ${path#$ROOT/}: $pattern"
    fi
  elif /usr/bin/grep -E -n "$pattern" "$path" >/dev/null; then
    fail "$label in ${path#$ROOT/}: $pattern"
  fi
}

removed_paths=(
  "Podfile"
  "Podfile.lock"
  "Jenkinsfile"
  "Pods"
  "docs/PrivatePods.md"
  "scripts/secrets/setup-private-pods.sh"
)

for path in "${removed_paths[@]}"; do
  ensure_path_absent "$path"
done

project_file="$ROOT/fearless.xcodeproj/project.pbxproj"
workspace_file="$ROOT/fearless.xcworkspace/contents.xcworkspacedata"
codecov_workflow="$ROOT/.github/workflows/codecov.yml"
codecov_config="$ROOT/codecov.yml"
coverage_summary="$ROOT/scripts/ci/coverage-summary.sh"
build_tools_package="$ROOT/Packages/FearlessBuildTools/Package.swift"
swiftlint_config="$ROOT/.swiftlint.yml"
swiftlint_baseline="$ROOT/.swiftlint-baseline.json"

for pattern in "[CP]" "Pods-" "libPods" "Check Pods Manifest.lock" "Pods/" "Podfile"; do
  ensure_pattern_absent \
    "$project_file" \
    "$pattern" \
    "Legacy CocoaPods Xcode project reference"
done

ensure_file "$build_tools_package"
ensure_file "$swiftlint_config"
ensure_file "$swiftlint_baseline"

for pattern in \
  "https://github.com/mac-cain13/R.swift.git" \
  "https://github.com/nicklockwood/SwiftFormat.git" \
  "https://github.com/realm/SwiftLint.git"; do
  ensure_pattern_present \
    "$build_tools_package" \
    "$pattern" \
    "Pinned build tool dependency"
done

for pattern in \
  "swiftlint not installed; skipping SwiftLint" \
  "swiftformat not installed; skipping SwiftFormat lint"; do
  ensure_pattern_absent \
    "$project_file" \
    "$pattern" \
    "Build phase fallback must run pinned tool instead of skipping"
done

ensure_pattern_present \
  "$project_file" \
  'xcrun --sdk macosx swift run --package-path \"$SRCROOT/Packages/FearlessBuildTools\" swiftlint lint' \
  "SwiftLint build phase fallback"
ensure_pattern_present \
  "$project_file" \
  'xcrun --sdk macosx swift run --package-path \"$SRCROOT/Packages/FearlessBuildTools\" swiftformat \"$SRCROOT/fearless\" --lint --config \"$SRCROOT/.swiftformat\"' \
  "SwiftFormat build phase fallback"
ensure_pattern_present \
  "$project_file" \
  '--baseline \"$SRCROOT/.swiftlint-baseline.json\"' \
  "SwiftLint baseline enforcement"
ensure_pattern_present \
  "$swiftlint_config" \
  "baseline: .swiftlint-baseline.json" \
  "SwiftLint baseline configuration"

ensure_pattern_absent \
  "$codecov_workflow" \
  "https://codecov.io/bash" \
  "Legacy Codecov bash uploader reference"
ensure_pattern_absent \
  "$codecov_workflow" \
  "bash <(curl" \
  "Legacy curl-piped uploader reference"
ensure_pattern_present \
  "$codecov_workflow" \
  "uses: codecov/codecov-action@v6" \
  "Codecov GitHub Action v6 upload"
ensure_pattern_present \
  "$codecov_workflow" \
  "id-token: write" \
  "Codecov OIDC permission"
ensure_pattern_present \
  "$codecov_workflow" \
  "plugins: xcode" \
  "Codecov Xcode coverage plugin"
ensure_pattern_present \
  "$codecov_workflow" \
  "swift_project: fearless" \
  "Codecov Swift project hint"
ensure_pattern_present \
  "$codecov_workflow" \
  "fail_ci_if_error: true" \
  "Codecov upload failure must fail CI"

ensure_pattern_present \
  "$codecov_config" \
  "coverage:" \
  "Codecov coverage status configuration"
ensure_pattern_present \
  "$codecov_config" \
  "project:" \
  "Codecov project coverage status"
ensure_pattern_present \
  "$codecov_config" \
  "patch:" \
  "Codecov patch coverage status"
ensure_pattern_present \
  "$codecov_config" \
  "threshold: 0%" \
  "Codecov patch coverage no-drop threshold"
ensure_pattern_present \
  "$codecov_config" \
  "- fearless" \
  "Codecov fearless coverage flag"
ensure_file "$coverage_summary"
[[ -x "$coverage_summary" ]] || fail "Coverage summary helper is not executable: ${coverage_summary#$ROOT/}"
ensure_pattern_present \
  "$coverage_summary" \
  "xcrun xccov view --report --json" \
  "Coverage summary must use Xcode coverage reports"
ensure_pattern_present \
  "$ROOT/scripts/test-matrix.sh" \
  "scripts/ci/coverage-summary.sh" \
  "test-matrix.sh must print coverage summaries from result bundles"

for pattern in "Pods.xcodeproj" "Pods/" "Podfile"; do
  ensure_pattern_absent \
    "$workspace_file" \
    "$pattern" \
    "Legacy CocoaPods workspace reference"
done

while IFS= read -r config; do
  for pattern in "Pods/" "Pods-" "COCOAPODS" "Target Support Files"; do
    ensure_pattern_absent \
      "$config" \
      "$pattern" \
      "Legacy CocoaPods xcconfig reference"
  done
done < <(/usr/bin/find "$ROOT/fearless/Configs" -type f -name "*.xcconfig" -print)

for path in \
  "$ROOT/.github" \
  "$ROOT/scripts/ci" \
  "$ROOT/scripts/secrets" \
  "$ROOT/README.md" \
  "$ROOT/ROADMAP.md" \
  "$ROOT/AGENTS.md"; do
  ensure_extended_pattern_absent \
    "$path" \
    "(Jenkins|jenkins|CocoaPods|PrivatePods|setup-private-pods)" \
    "Legacy CI/dependency-management reference"
done

echo "[check-modern-tooling-contracts] OK"
