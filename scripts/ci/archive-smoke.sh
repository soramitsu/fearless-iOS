#!/usr/bin/env bash
set -euo pipefail

# Runs an unsigned archive build to validate the iOS archive path without
# requiring Apple signing material. Set REQUIRE_SIGNED_ARCHIVE=1 to fail when
# no local signing identity/provisioning profile is available.

ROOT="${1:-$(pwd)}"
WORKSPACE="${WORKSPACE:-fearless.xcworkspace}"
SCHEME="${SCHEME:-fearless}"
CONFIGURATION="${CONFIGURATION:-Dev}"
SP_DIR="${SP_DIR:-$ROOT/SourcePackages}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/fearless-smoke.xcarchive}"
REQUIRE_SIGNED_ARCHIVE="${REQUIRE_SIGNED_ARCHIVE:-0}"
SKIP_BOOTSTRAP="${SKIP_BOOTSTRAP:-0}"

cd "$ROOT"

if [[ "$SKIP_BOOTSTRAP" != "1" ]]; then
  SP_DIR="$SP_DIR" bash scripts/ci/bootstrap.sh
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"
rm -rf "$ARCHIVE_PATH"

echo "[archive-smoke] Running unsigned ${CONFIGURATION} archive"
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -clonedSourcePackagesDirPath "$SP_DIR" \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean archive

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "[archive-smoke] ERROR: archive was not created at $ARCHIVE_PATH" >&2
  exit 1
fi

echo "[archive-smoke] Unsigned archive OK: $ARCHIVE_PATH"

identity_count="$(security find-identity -v -p codesigning 2>/dev/null | awk '/valid identities found/ {print $1; found=1} END { if (!found) print 0 }')"
profiles_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
if [[ -d "$profiles_dir" ]]; then
  profile_count="$(find "$profiles_dir" -maxdepth 1 -name '*.mobileprovision' -print 2>/dev/null | wc -l | tr -d ' ')"
else
  profile_count=0
fi

if [[ "$identity_count" == "0" || "$profile_count" == "0" ]]; then
  echo "[archive-smoke] Signing material missing: ${identity_count} code signing identit(ies), ${profile_count} provisioning profile(s)."
  if [[ "$REQUIRE_SIGNED_ARCHIVE" == "1" ]]; then
    exit 2
  fi
else
  echo "[archive-smoke] Signing material present; run a signed archive without CODE_SIGNING_ALLOWED=NO for release validation."
fi
