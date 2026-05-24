#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
EXPECTED_SSF_REVISION="${2:-3ad0fe928333c9ac28972e3669ca733c6972f060}"

WORKSPACE_RESOLVED="$ROOT/fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved"
PROJECT_RESOLVED="$ROOT/fearless.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
FEARLESS_UTILS_PACKAGE="$ROOT/Packages/FearlessUtilsCompat/Package.swift"
ENFORCE_SCRIPT="$ROOT/scripts/deps/enforce-ssf-pin.sh"
REFERENCE_MIRRORS="$ROOT/scripts/deps/mirrors.json"
WORKSPACE_MIRRORS="$ROOT/fearless.xcworkspace/xcshareddata/swiftpm/configuration/mirrors.json"
PROJECT_MIRRORS="$ROOT/fearless.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/configuration/mirrors.json"
PROJECT_FILE="$ROOT/fearless.xcodeproj/project.pbxproj"
WEB3_SOURCE_URL="https://github.com/soramitsu/web3-swift"
STALE_WEB3_SOURCE_URL="https://github.com/bnsports/Web3.swift.git"

fail() {
  echo "[check-swiftpm-consistency] $1" >&2
  exit 1
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "Missing required file: $file"
}

extract_shared_features_revision() {
  local file="$1"
  awk '
    /"identity"[[:space:]]*:[[:space:]]*"shared-features-spm"/ { in_pkg=1 }
    in_pkg && /"revision"[[:space:]]*:/ {
      match($0, /"revision"[[:space:]]*:[[:space:]]*"[^"]+"/)
      if (RSTART > 0) {
        value = substr($0, RSTART, RLENGTH)
        gsub(/.*"revision"[[:space:]]*:[[:space:]]*"/, "", value)
        gsub(/".*/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

require_file "$WORKSPACE_RESOLVED"
require_file "$PROJECT_RESOLVED"
require_file "$FEARLESS_UTILS_PACKAGE"
require_file "$ENFORCE_SCRIPT"
require_file "$REFERENCE_MIRRORS"
require_file "$WORKSPACE_MIRRORS"
require_file "$PROJECT_MIRRORS"
require_file "$PROJECT_FILE"

if ! cmp -s "$WORKSPACE_RESOLVED" "$PROJECT_RESOLVED"; then
  fail "Committed Package.resolved files differ:\n  $WORKSPACE_RESOLVED\n  $PROJECT_RESOLVED"
fi

if ! cmp -s "$REFERENCE_MIRRORS" "$WORKSPACE_MIRRORS"; then
  fail "Workspace mirrors.json differs from reference mirrors.json:\n  $REFERENCE_MIRRORS\n  $WORKSPACE_MIRRORS"
fi

if ! cmp -s "$REFERENCE_MIRRORS" "$PROJECT_MIRRORS"; then
  fail "Project mirrors.json differs from reference mirrors.json:\n  $REFERENCE_MIRRORS\n  $PROJECT_MIRRORS"
fi

WORKSPACE_SSF_REVISION="$(extract_shared_features_revision "$WORKSPACE_RESOLVED")"
[[ -n "$WORKSPACE_SSF_REVISION" ]] || fail "Could not extract shared-features-spm revision from $WORKSPACE_RESOLVED"

if [[ "$WORKSPACE_SSF_REVISION" != "$EXPECTED_SSF_REVISION" ]]; then
  fail "Workspace Package.resolved shared-features-spm revision is $WORKSPACE_SSF_REVISION, expected $EXPECTED_SSF_REVISION"
fi

if ! grep -Fq "$EXPECTED_SSF_REVISION" "$PROJECT_RESOLVED"; then
  fail "Project Package.resolved does not contain expected shared-features-spm revision $EXPECTED_SSF_REVISION"
fi

if ! grep -Fq "$EXPECTED_SSF_REVISION" "$FEARLESS_UTILS_PACKAGE"; then
  fail "FearlessUtilsCompat package is not pinned to shared-features-spm revision $EXPECTED_SSF_REVISION"
fi

if ! grep -Fq "REVISION=\"\${1:-$EXPECTED_SSF_REVISION}\"" "$ENFORCE_SCRIPT"; then
  fail "enforce-ssf-pin.sh default revision is not $EXPECTED_SSF_REVISION"
fi

for resolved in "$WORKSPACE_RESOLVED" "$PROJECT_RESOLVED"; do
  if grep -Fq '"identity" : "web3.swift"' "$resolved"; then
    fail "Stale web3.swift identity still exists in committed Package.resolved: $resolved"
  fi

  if grep -Fq "$STALE_WEB3_SOURCE_URL" "$resolved"; then
    fail "Stale Web3 source URL still exists in committed Package.resolved: $resolved"
  fi

  if ! grep -Fq "$WEB3_SOURCE_URL" "$resolved"; then
    fail "Committed Package.resolved does not contain expected Web3 source URL $WEB3_SOURCE_URL: $resolved"
  fi
done

if grep -Fq "$STALE_WEB3_SOURCE_URL" "$PROJECT_FILE"; then
  fail "Xcode project still references stale Web3 source URL $STALE_WEB3_SOURCE_URL"
fi

if ! grep -Fq "$WEB3_SOURCE_URL" "$PROJECT_FILE"; then
  fail "Xcode project does not reference expected Web3 source URL $WEB3_SOURCE_URL"
fi

if ! grep -Fq "$WEB3_SOURCE_URL" "$ENFORCE_SCRIPT"; then
  fail "enforce-ssf-pin.sh does not normalize Package.resolved Web3 sources to $WEB3_SOURCE_URL"
fi

if ! grep -Fq 'https://github.com/bnsports/Web3.swift.git' "$REFERENCE_MIRRORS" || ! grep -Fq 'https://github.com/soramitsu/web3-swift' "$REFERENCE_MIRRORS"; then
  fail "Reference mirrors.json does not contain the expected Web3 mirror mapping"
fi

echo "[check-swiftpm-consistency] OK"
echo "[check-swiftpm-consistency] shared-features-spm revision: $WORKSPACE_SSF_REVISION"
