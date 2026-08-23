#!/usr/bin/env bash
set -euo pipefail

# Builds and audits the only archive eligible for the 4.2.0 redesign handoff.
# It derives provenance from an exact clean HEAD and never uploads anything.

umask 077

readonly LOG_PREFIX="[ios-release-archive]"
readonly EXPECTED_BUNDLE="jp.co.soramitsu.fearlesswallet"
readonly EXPECTED_VERSION="4.2.0"
readonly EXPECTED_BASE_SOURCE_COMMIT="2e45e55dc03ad904598e730cfb5994fb5c1072dc"
readonly EXPECTED_SIGNING_IDENTITY="Apple Distribution: Soramitsu Co., Ltd. (YLWWUD25VZ)"
readonly EXPECTED_SIGNING_CERTIFICATE_SHA1="84AB95335BE14CAE9B050A353910F86FF2F9539B"
readonly EXPECTED_PROFILE_NAME="Fearless App Store 2026.7.26"
readonly EXPECTED_PROFILE_UUID="0d51265e-4b53-4a1f-814a-436dc9ca087b"
# Build 2026.8.10 exposed the missing public Substrate compatibility model.
# Build 2026.8.13 corrected storage migration but exposed the iOS 26 tab-bar
# replacement regression. Build 2026.8.14 was consumed by an App Store Connect
# upload with warnings; build 2026.8.15 corrected the legacy bar's visibility
# but still omitted the completed redesign. Build 2026.8.17 integrated the
# redesign but omitted production Bitcoin catalog/account wiring. Build
# 2026.8.18 added native Bitcoin but accidentally default-disabled Polkaswap
# mutations and could strand the Polkaswap tab during asynchronous startup.
# 2026.8.19 restored the feature but left its modal-era action under the
# redesigned translucent tab bar. 2026.8.20 keeps the action and banners in
# the tab-aware safe area, but existing wallets without a provisioned BIP-84
# account still could not see Bitcoin. 2026.8.21 makes the app-owned Bitcoin
# row visible, retries safe provisioning, and exposes mnemonic-only recovery.
# 2026.8.22 adds app-owned Taira Testnet catalog/account provisioning, I105
# receive and remote read paths while keeping production Iroha Send disabled.
# 2026.8.23 persists Bitcoin and Taira locally before the remote catalog fetch,
# so an offline or stalled launch cannot hide either app-owned network.
# 2026.8.24 ships the official Bitcoin mark, uses Mempool.space's public
# Esplora API, and derives standard BIP84 accounts only from authentic stored
# root mnemonic entropy without inventing an unrecoverable alternate identity.
# 2026.8.25 binds Taira reads to taira.sora.org and to canonical XOR
# xor#universal from the reviewed Iroha optimizations SDK wire contract while
# keeping production Iroha Send disabled.
# 2026.8.26 bundles the canonical Bitcoin mark and adds the explicit,
# recoverable raw wallet-seed bridge while retaining Mempool.space as the sole
# production Bitcoin service.
# 2026.8.27 preserves the completed seed-adoption result across the asynchronous
# UI handoff so the confirmed Bitcoin/Taira accounts are actually saved.
# 2026.8.28 performs legacy seed adoption from one confirmation sheet and
# conflict-safely merges dedicated accounts into the current selected wallet.
# 2026.8.29 makes the selected action independent of dismissal callback order,
# persists through the production adoption path, and surfaces seed failures.
# 2026.8.30 routes wallets without recoverable local root entropy directly to
# recovery, accepts an exact 32-byte raw wallet seed for Bitcoin, derives the
# standard BIP84 identity, and persists account-scoped signer entropy.
# 2026.8.31 adds the missing fresh-key path for restored wallets, keeps Create
# and Import available when no compatible wallet seed exists, and synchronizes
# pasted recovery input before submission.
# Reconfirm successor uniqueness read-only immediately before archive.
readonly EXPECTED_BUILD="2026.8.31"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

fail() {
  printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/ci/build-audited-ios-release-archive.sh \
    --archive /absolute/new/path/fearless.xcarchive \
    --receipt /absolute/new/path/signed-archive-audit.json

Preconditions:
  - exact clean git HEAD, including no untracked files, descended from the
    distributed 4.2.0 (2026.7.28) source commit;
  - App Store Connect read-only uniqueness check for 4.2.0 (2026.8.31);
  - App Store distribution profile for the production App ID, with
    group.jp.co.soramitsu.fearlesswallet and Apple default keychain groups.

This command creates a local archive and receipt. It does not export, upload,
publish, tag, commit, or push.
USAGE
}

require_option_value() {
  local option="$1"
  local remaining="$2"
  [[ "$remaining" -ge 2 ]] || fail "$option requires a value"
}

archive=""
receipt=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --archive)
      require_option_value "$1" "$#"
      archive="$2"
      shift 2
      ;;
    --receipt)
      require_option_value "$1" "$#"
      receipt="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ "$archive" == /* && "$archive" == *.xcarchive ]] ||
  fail "--archive must be an absolute .xcarchive path"
[[ ! -e "$archive" && ! -L "$archive" ]] ||
  fail "--archive must not already exist"
[[ -d "$(dirname "$archive")" && ! -L "$(dirname "$archive")" ]] ||
  fail "--archive parent must be a real existing directory"
[[ "$receipt" == /* ]] || fail "--receipt must be an absolute path"
[[ ! -e "$receipt" && ! -L "$receipt" ]] ||
  fail "--receipt must not already exist"
[[ -d "$(dirname "$receipt")" && ! -L "$(dirname "$receipt")" ]] ||
  fail "--receipt parent must be a real existing directory"

command -v git >/dev/null 2>&1 || fail "git is unavailable"
command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild is unavailable"
command -v shasum >/dev/null 2>&1 || fail "shasum is unavailable"
command -v security >/dev/null 2>&1 || fail "security is unavailable"
security find-identity -v -p codesigning 2>/dev/null |
  grep -Fq "$EXPECTED_SIGNING_CERTIFICATE_SHA1 \"$EXPECTED_SIGNING_IDENTITY\"" ||
  fail "the exact reviewed Apple Distribution signing identity is not installed"

cd "$REPO_ROOT"
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] ||
  fail "release archive requires an exact clean worktree, including no untracked files"
git diff --quiet --ignore-submodules -- ||
  fail "release archive source differs from HEAD"
git diff --cached --quiet --ignore-submodules -- ||
  fail "release archive index differs from HEAD"

source_commit="$(git rev-parse --verify HEAD)"
[[ "$source_commit" =~ ^[0-9A-Fa-f]{40}$ ]] ||
  fail "could not derive an exact source commit"
git cat-file -e "${source_commit}^{commit}" ||
  fail "derived source provenance is not a commit"
git cat-file -e "${EXPECTED_BASE_SOURCE_COMMIT}^{commit}" ||
  fail "the exact distributed 4.2.0 (2026.7.28) source commit is unavailable"
git merge-base --is-ancestor "$EXPECTED_BASE_SOURCE_COMMIT" "$source_commit" ||
  fail "release source is not descended from the exact distributed 4.2.0 (2026.7.28) source"

IOS_EXPECTED_BUILD_NUMBER="$EXPECTED_BUILD" \
IOS_RELEASE_SOURCE_PACKAGES_DIR="${IOS_RELEASE_SOURCE_PACKAGES_DIR:-}" \
  bash "$SCRIPT_DIR/audit-ios-release-identity.sh"
bash "$REPO_ROOT/scripts/storage/audit-user-storage-compatibility-models.sh"
bash "$REPO_ROOT/scripts/storage/audit-substrate-storage-compatibility-models.sh"

xcodebuild_arguments=(
  -workspace "$REPO_ROOT/fearless.xcworkspace"
  -scheme fearless
  -configuration Release
  -destination "generic/platform=iOS"
  -archivePath "$archive"
)
if [[ -n "${IOS_RELEASE_SOURCE_PACKAGES_DIR:-}" ]]; then
  xcodebuild_arguments+=(
    -clonedSourcePackagesDirPath "$IOS_RELEASE_SOURCE_PACKAGES_DIR"
    -disableAutomaticPackageResolution
    -skipPackageUpdates
  )
fi
xcodebuild_arguments+=(
  "CURRENT_PROJECT_VERSION=$EXPECTED_BUILD"
  "MARKETING_VERSION=$EXPECTED_VERSION"
  "FEARLESS_GIT_COMMIT=$source_commit"
  # Signing is intentionally target-scoped in the application's Release build
  # configuration. Any signing setting passed here would apply to every Pod,
  # Swift package, and resource bundle in the workspace. The source identity
  # audit above and signed-artifact audit below fail closed on the exact team,
  # distribution identity, App Store profile, and production entitlements.
  clean
  archive
)

printf '%s\n' \
  "$LOG_PREFIX building local Release archive from clean commit $source_commit"
xcodebuild "${xcodebuild_arguments[@]}"

bash "$SCRIPT_DIR/materialize-embedded-framework-dsyms.sh" "$archive"

[[ "$(git rev-parse --verify HEAD)" == "$source_commit" ]] ||
  fail "HEAD changed while the release archive was built"
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] ||
  fail "tracked or untracked source state changed while the archive was built"

app_path="$archive/Products/Applications/fearless.app"
[[ -d "$app_path" && ! -L "$app_path" ]] ||
  fail "archive did not produce exactly the expected application path"
executable_name="$(
  /usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" \
    "$app_path/Info.plist" 2>/dev/null
)" || fail "archive app has no executable identity"
[[ "$executable_name" =~ ^[A-Za-z0-9._-]+$ ]] ||
  fail "archive executable identity is unsafe"
executable_sha="$(
  shasum -a 256 "$app_path/$executable_name" | awk '{print $1}'
)"
archive_sha="$(bash "$SCRIPT_DIR/hash-ios-archive.sh" "$archive")"

bash "$SCRIPT_DIR/audit-ios-signed-release-artifact.sh" \
  --archive "$archive" \
  --expected-git-sha "$source_commit" \
  --expected-build "$EXPECTED_BUILD" \
  --expected-executable-sha256 "$executable_sha" \
  --expected-archive-sha256 "$archive_sha" \
  --expected-signing-certificate-sha1 "$EXPECTED_SIGNING_CERTIFICATE_SHA1" \
  --expected-profile-uuid "$EXPECTED_PROFILE_UUID" \
  --expected-profile-name "$EXPECTED_PROFILE_NAME" \
  --receipt "$receipt"

printf '%s\n' \
  "$LOG_PREFIX PASS: local 4.2.0 ($EXPECTED_BUILD) archive is bound to clean HEAD $source_commit"
