#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
PREFERRED_NAME="${PREFERRED_NAME:-iPhone 16}"

fail() {
  echo "[test-local-packages] $1" >&2
  exit 1
}

run_in_package() {
  local package_path="$1"
  shift

  [[ -d "$ROOT/$package_path" ]] || fail "Missing package directory: $ROOT/$package_path"
  echo "[test-local-packages] $package_path: $*"
  (cd "$ROOT/$package_path" && "$@")
}

validate_manifest() {
  local package_path="$1"

  [[ -d "$ROOT/$package_path" ]] || fail "Missing package directory: $ROOT/$package_path"
  echo "[test-local-packages] $package_path: swift package dump-package"
  (cd "$ROOT/$package_path" && swift package dump-package >/dev/null)
}

select_destination() {
  if [[ -n "${LOCAL_PACKAGE_DESTINATION:-}" ]]; then
    echo "$LOCAL_PACKAGE_DESTINATION"
    return 0
  fi

  [[ -x "$ROOT/scripts/ci/select-simulator.sh" ]] || fail "Missing simulator selector"

  local raw
  local udid
  raw="$(
    LOG_PREFIX="[test-local-packages]" \
      PREFERRED_NAME="$PREFERRED_NAME" \
      ALLOW_CREATE="${ALLOW_CREATE_SIMULATOR:-1}" \
      BOOT_SIMULATOR=0 \
      "$ROOT/scripts/ci/select-simulator.sh"
  )"
  udid="$(printf '%s\n' "$raw" | awk 'match($0, /[A-Fa-f0-9-]{36}/) { print substr($0, RSTART, RLENGTH); exit }')"
  [[ -n "$udid" ]] || fail "Failed to parse simulator UDID from selector output: $raw"

  local destination="platform=iOS Simulator,id=${udid}"
  case "$(uname -m)" in
    arm64|x86_64)
      destination+=",arch=$(uname -m)"
      ;;
  esac

  echo "$destination"
}

cd "$ROOT"

manifest_packages=(
  "Packages/FearlessBuildTools"
  "Packages/FearlessDependencies"
  "Packages/FearlessFoundation"
  "Packages/FearlessSecureStorage"
  "Packages/FearlessTestSupport"
  "Packages/FearlessUI"
  "Packages/FearlessUtilsCompat"
)

swift_build_packages=(
  "Packages/FearlessBuildTools"
  "Packages/FearlessSecureStorage"
  "Packages/FearlessTestSupport"
)

echo "[test-local-packages] Validating package manifests"
for package_path in "${manifest_packages[@]}"; do
  validate_manifest "$package_path"
done

echo "[test-local-packages] Running host SwiftPM package checks"
for package_path in "${swift_build_packages[@]}"; do
  run_in_package "$package_path" swift build
done
run_in_package "Packages/FearlessSecureStorage" swift test
run_in_package "Packages/FearlessTestSupport" swift test

if [[ "${SKIP_IOS_PACKAGE_BUILDS:-0}" == "1" ]]; then
  echo "[test-local-packages] Skipping iOS package builds because SKIP_IOS_PACKAGE_BUILDS=1"
  exit 0
fi

destination="$(select_destination)"
echo "[test-local-packages] Using simulator destination: $destination"

ios_package_builds=(
  "Packages/FearlessSecureStorage:FearlessSecureStorage"
)

ios_package_tests=(
  "Packages/FearlessFoundation:FearlessFoundation"
  "Packages/FearlessTestSupport:FearlessTestSupport"
  "Packages/FearlessUI:FearlessUI"
)

echo "[test-local-packages] Building local iOS packages"
for item in "${ios_package_builds[@]}"; do
  package_path="${item%%:*}"
  scheme="${item##*:}"
  run_in_package "$package_path" xcodebuild -quiet -scheme "$scheme" -destination "$destination" build
done

echo "[test-local-packages] Testing local iOS packages"
for item in "${ios_package_tests[@]}"; do
  package_path="${item%%:*}"
  scheme="${item##*:}"
  run_in_package "$package_path" xcodebuild -quiet -scheme "$scheme" -destination "$destination" test
done

echo "[test-local-packages] OK"
