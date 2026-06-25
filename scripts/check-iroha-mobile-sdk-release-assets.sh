#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/check-iroha-mobile-sdk-release-assets.sh --release-dir <dir> [--version <version>]
  scripts/check-iroha-mobile-sdk-release-assets.sh --download --tag <tag> [--repo <owner/repo>]
  scripts/check-iroha-mobile-sdk-release-assets.sh --self-test

Validates the Apple Iroha mobile SDK release assets produced by ../iroha:
  - NoritoBridge-<version>.xcframework.zip
  - NoritoBridge-<version>.artifacts.json
  - SHA256SUMS-apple-<version>.txt or SHA256SUMS-all-<version>.txt
  - mobile-sdk-apple-<version>.artifacts.json or mobile-sdk-all-<version>.artifacts.json

The XCFramework zip must contain iOS device, iOS simulator, and macOS slices
with libNoritoBridge.a, headers, and module maps.
USAGE
}

RELEASE_DIR=""
VERSION=""
DOWNLOAD=0
SELF_TEST=0
REPO="${IROHA_MOBILE_SDK_RELEASE_REPO:-hyperledger/iroha}"
TAG="${IROHA_MOBILE_SDK_RELEASE_TAG:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-dir)
      shift
      RELEASE_DIR="${1:-}"
      ;;
    --release-dir=*)
      RELEASE_DIR="${1#*=}"
      ;;
    --version)
      shift
      VERSION="${1:-}"
      ;;
    --version=*)
      VERSION="${1#*=}"
      ;;
    --download)
      DOWNLOAD=1
      ;;
    --tag)
      shift
      TAG="${1:-}"
      ;;
    --tag=*)
      TAG="${1#*=}"
      ;;
    --repo)
      shift
      REPO="${1:-}"
      ;;
    --repo=*)
      REPO="${1#*=}"
      ;;
    --self-test)
      SELF_TEST=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[iroha-sdk-assets] ERROR: unexpected argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

fail() {
  echo "[iroha-sdk-assets] ERROR: $*" >&2
  exit 1
}

hash_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  else
    fail "shasum or sha256sum is required"
  fi
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

zip_entries() {
  unzip -Z1 "$1" 2>/dev/null || fail "not a readable zip archive: $1"
}

require_zip_entry() {
  local archive="$1"
  local pattern="$2"
  local label="$3"
  local entries
  entries="$(zip_entries "$archive")"
  grep -Eq "$pattern" <<<"$entries" || fail "missing $label in $(basename "$archive")"
}

infer_version() {
  local dir="$1"
  local files=()
  local file base
  while IFS= read -r file; do
    files+=("$file")
  done < <(find "$dir" -maxdepth 1 -type f -name 'NoritoBridge-*.xcframework.zip' | sort)

  [[ ${#files[@]} -eq 1 ]] || fail "expected exactly one NoritoBridge-*.xcframework.zip in $dir, found ${#files[@]}"
  base="$(basename "${files[0]}")"
  base="${base#NoritoBridge-}"
  printf '%s' "${base%.xcframework.zip}"
}

download_release_assets() {
  [[ -n "$TAG" ]] || fail "--download requires --tag or IROHA_MOBILE_SDK_RELEASE_TAG"
  require_tool gh
  RELEASE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/iroha-apple-sdk-assets.XXXXXX")"
  VERSION="$TAG"
  gh release download "$TAG" \
    --repo "$REPO" \
    --dir "$RELEASE_DIR" \
    --pattern "NoritoBridge-${TAG}.xcframework.zip" \
    --pattern "NoritoBridge-${TAG}.artifacts.json" \
    --pattern "SHA256SUMS-apple-${TAG}.txt" \
    --pattern "mobile-sdk-apple-${TAG}.artifacts.json"
}

validate_release_dir() {
  require_tool unzip

  [[ -n "$RELEASE_DIR" ]] || fail "--release-dir is required unless --download is used"
  [[ -d "$RELEASE_DIR" ]] || fail "release dir does not exist: $RELEASE_DIR"

  if [[ -z "$VERSION" ]]; then
    VERSION="$(infer_version "$RELEASE_DIR")"
  fi

  local apple_zip="$RELEASE_DIR/NoritoBridge-${VERSION}.xcframework.zip"
  local bridge_manifest="$RELEASE_DIR/NoritoBridge-${VERSION}.artifacts.json"
  local checksums="$RELEASE_DIR/SHA256SUMS-apple-${VERSION}.txt"
  local manifest="$RELEASE_DIR/mobile-sdk-apple-${VERSION}.artifacts.json"
  local sha slice

  [[ -f "$apple_zip" ]] || fail "missing Apple XCFramework zip: $apple_zip"
  [[ -f "$bridge_manifest" ]] || fail "missing NoritoBridge artifact manifest: $bridge_manifest"
  if [[ ! -f "$checksums" ]]; then
    checksums="$RELEASE_DIR/SHA256SUMS-all-${VERSION}.txt"
  fi
  [[ -f "$checksums" ]] || fail "missing checksum file for version $VERSION"
  if [[ ! -f "$manifest" ]]; then
    manifest="$RELEASE_DIR/mobile-sdk-all-${VERSION}.artifacts.json"
  fi
  [[ -f "$manifest" ]] || fail "missing mobile SDK artifact manifest for version $VERSION"

  sha="$(hash_file "$apple_zip")"
  grep -F "$(basename "$apple_zip")" "$checksums" | grep -Fq "$sha" ||
    fail "checksum file does not match $(basename "$apple_zip")"
  grep -Fq "\"version\": \"$VERSION\"" "$manifest" || fail "mobile SDK manifest version mismatch"
  grep -Fq "$(basename "$apple_zip")" "$manifest" || fail "mobile SDK manifest does not list Apple XCFramework zip"
  grep -Fq "\"version\": " "$bridge_manifest" || fail "bridge manifest missing version"

  for slice in ios-arm64 ios-arm64_x86_64-simulator macos-arm64; do
    grep -Eq "\"$slice\"[[:space:]]*:[[:space:]]*\"[[:xdigit:]]{64}\"" "$bridge_manifest" ||
      fail "bridge manifest missing SHA-256 hash for $slice"
    require_zip_entry "$apple_zip" "^NoritoBridge\\.xcframework/$slice/libNoritoBridge\\.a$" "$slice static library"
    require_zip_entry "$apple_zip" "^NoritoBridge\\.xcframework/$slice/Headers/NoritoBridge\\.h$" "$slice umbrella header"
    require_zip_entry "$apple_zip" "^NoritoBridge\\.xcframework/$slice/Headers/connect_norito_bridge\\.h$" "$slice bridge header"
    require_zip_entry "$apple_zip" "^NoritoBridge\\.xcframework/$slice/Headers/module\\.modulemap$" "$slice module map"
  done
  require_zip_entry "$apple_zip" '^NoritoBridge\.xcframework/Info\.plist$' "XCFramework Info.plist"

  echo "[iroha-sdk-assets] Apple Iroha SDK assets validated for version $VERSION"
}

make_fixture() {
  local dir="$1"
  local version="$2"
  local omit_sim="${3:-0}"
  local omit_manifest_hash="${4:-0}"
  local stage="$dir/NoritoBridge.xcframework"
  local zip_path="$dir/NoritoBridge-${version}.xcframework.zip"
  local sha slice

  mkdir -p "$stage"
  printf '<plist><dict><key>AvailableLibraries</key></dict></plist>\n' > "$stage/Info.plist"
  for slice in ios-arm64 ios-arm64_x86_64-simulator macos-arm64; do
    if [[ "$omit_sim" == "1" && "$slice" == "ios-arm64_x86_64-simulator" ]]; then
      continue
    fi
    mkdir -p "$stage/$slice/Headers"
    printf 'lib\n' > "$stage/$slice/libNoritoBridge.a"
    printf 'header\n' > "$stage/$slice/Headers/NoritoBridge.h"
    printf 'header\n' > "$stage/$slice/Headers/connect_norito_bridge.h"
    printf 'module NoritoBridge {}\n' > "$stage/$slice/Headers/module.modulemap"
  done

  (cd "$dir" && zip -qr "$(basename "$zip_path")" NoritoBridge.xcframework)
  sha="$(hash_file "$zip_path")"
  printf '%s  %s\n' "$sha" "$zip_path" > "$dir/SHA256SUMS-apple-${version}.txt"
  if [[ "$omit_manifest_hash" == "1" ]]; then
    cat > "$dir/NoritoBridge-${version}.artifacts.json" <<JSON
{
  "version": "$version",
  "hashes": {
    "ios-arm64": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "macos-arm64": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  }
}
JSON
  else
    cat > "$dir/NoritoBridge-${version}.artifacts.json" <<JSON
{
  "version": "$version",
  "hashes": {
    "ios-arm64": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "ios-arm64_x86_64-simulator": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "macos-arm64": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  }
}
JSON
  fi
  cat > "$dir/mobile-sdk-apple-${version}.artifacts.json" <<JSON
{
  "version": "$version",
  "mode": "apple",
  "artifacts": [
    {"kind":"apple-xcframework","name":"$(basename "$zip_path")","path":"$zip_path","sha256":"$sha","bytes":1}
  ]
}
JSON
  rm -rf "$stage"
}

run_self_test() {
  require_tool zip
  require_tool unzip
  local tmp valid missing_slice missing_hash missing_checksums
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/iroha-apple-assets-test.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT

  valid="$tmp/valid"
  mkdir -p "$valid"
  make_fixture "$valid" "v0.1.0"
  bash "$0" --release-dir "$valid" --version "v0.1.0" >/dev/null

  missing_slice="$tmp/missing-slice"
  mkdir -p "$missing_slice"
  make_fixture "$missing_slice" "v0.1.0" 1
  if bash "$0" --release-dir "$missing_slice" --version "v0.1.0" >/dev/null 2>&1; then
    fail "self-test expected missing simulator slice validation to fail"
  fi

  missing_hash="$tmp/missing-hash"
  mkdir -p "$missing_hash"
  make_fixture "$missing_hash" "v0.1.0" 0 1
  if bash "$0" --release-dir "$missing_hash" --version "v0.1.0" >/dev/null 2>&1; then
    fail "self-test expected missing bridge manifest hash validation to fail"
  fi

  missing_checksums="$tmp/missing-checksums"
  mkdir -p "$missing_checksums"
  make_fixture "$missing_checksums" "v0.1.0"
  rm -f "$missing_checksums/SHA256SUMS-apple-v0.1.0.txt"
  if bash "$0" --release-dir "$missing_checksums" --version "v0.1.0" >/dev/null 2>&1; then
    fail "self-test expected missing checksum validation to fail"
  fi

  echo "[iroha-sdk-assets-test] Apple release asset checks passed"
}

if [[ "$SELF_TEST" == "1" ]]; then
  run_self_test
  exit 0
fi

if [[ "$DOWNLOAD" == "1" ]]; then
  download_release_assets
fi

validate_release_dir
