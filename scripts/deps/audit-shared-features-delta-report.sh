#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
REPORT_FILE=""

usage() {
  cat <<'USAGE'
Usage: scripts/deps/audit-shared-features-delta-report.sh [ROOT] [--write-report <path>]

Validates the repo-owned shared-features-spm compatibility delta and optionally
writes a JSON report for CI/release review. This does not mutate SwiftPM
checkouts; it records why the current checkout-mutation scripts still exist and
what upstream/source changes are needed to remove them.
USAGE
}

while (($#)); do
  case "$1" in
    --write-report)
      [[ $# -ge 2 ]] || { echo "[shared-features-delta][error] --write-report requires a path" >&2; exit 2; }
      REPORT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "$1" == --* ]]; then
        echo "[shared-features-delta][error] Unknown argument: $1" >&2
        usage >&2
        exit 2
      fi
      ROOT="$1"
      shift
      ;;
  esac
done

failures=()

record_failure() {
  failures+=("$1")
  echo "[shared-features-delta][warn] $1" >&2
}

require_file() {
  local file="$1"
  local label="$2"
  [[ -f "$file" ]] || record_failure "$label missing: $file"
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  [[ -f "$file" ]] || return 0
  /usr/bin/grep -Fq "$pattern" "$file" || record_failure "$label missing in $file"
}

json_escape() {
  /usr/bin/perl -pe 's/\\/\\\\/g; s/"/\\"/g; s/\n//g'
}

sha256_file() {
  local file="$1"

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  else
    record_failure "No SHA-256 tool available for $file"
    printf 'missing-sha256-tool'
  fi
}

extract_shared_features_revision() {
  local resolved="$1"
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
  ' "$resolved"
}

SPM_FIXES="$ROOT/scripts/spm-shared-features-fixes.sh"
STABILITY_DOC="$ROOT/docs/SSFStability.md"
UPSTREAM_DELTA_DOC="$ROOT/docs/SSFNativeCryptoUpstreamDelta.md"
WORKSPACE_RESOLVED="$ROOT/fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved"
MODULEMAP_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto.module.modulemap"
UMBRELLA_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto-umbrella.h"
LINKER_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto.linker-settings.swiftfrag"
EXPORT_SCRIPT="$ROOT/scripts/deps/export-native-crypto-upstream-delta.sh"

require_file "$SPM_FIXES" "shared-features compatibility patch script"
require_file "$STABILITY_DOC" "SSF stability documentation"
require_file "$UPSTREAM_DELTA_DOC" "native crypto upstream delta documentation"
require_file "$WORKSPACE_RESOLVED" "workspace Package.resolved"
require_file "$MODULEMAP_TEMPLATE" "IrohaCrypto modulemap template"
require_file "$UMBRELLA_TEMPLATE" "IrohaCrypto umbrella template"
require_file "$LINKER_TEMPLATE" "IrohaCrypto linker-settings template"
require_file "$EXPORT_SCRIPT" "native crypto delta export script"

DELTA_IDS=(
  "web3-mirror-normalization"
  "ssfmodels-explicit-dependencies"
  "ssfpolkaswap-explicit-dependencies"
  "sorakeystore-runtime-namespace"
  "ethereum-private-key-data-array"
  "addressfactory-compatibility-cleanup"
  "scrypt-simulator-arch-guard"
  "native-crypto-sidecar-pruning"
  "ssfpools-public-initializers"
  "native-crypto-contract-reapply"
  "strict-required-patch-accounting"
)

DELTA_LABELS=(
  "Web3 mirror normalization"
  "SSFModels explicit BigInt and RobinHood dependencies"
  "SSFPolkaswap explicit build dependencies"
  "SoraKeystore Objective-C runtime namespace"
  "EthereumPrivateKey Data to Array conversion"
  "AddressFactory compatibility shim cleanup"
  "scrypt simulator architecture guard"
  "native crypto framework sidecar pruning"
  "SSFPools public initializer export"
  "native crypto package/modulemap contract reapply"
  "strict required patch accounting"
)

DELTA_PATTERNS=(
  "https://github.com/soramitsu/web3-swift"
  "BigInt.git"
  "Updated SSFPolkaswap dependencies"
  "SSFSoraKeystoreKeychain"
  "EthereumPrivateKey(privateKey: Array"
  "AddressFactory compatibility shims"
  "__SSSE3__"
  "libsr25519crust.a"
  "PooledAssetInfo"
  "apply_native_crypto_contracts"
  "No shared-features-spm checkout was available to patch"
)

REMOVAL_READINESS_STATUS="blocked"
REMOVAL_REQUIRED_ACTION="Upstream or vendor every carriedDeltas entry into the pinned shared-features-spm source, then remove post-resolution checkout mutation from CI and release scripts."
REMOVAL_VERIFICATION_COMMAND='bash scripts/deps/test-shared-features-delta-report.sh && bash scripts/deps/audit-shared-features-delta-report.sh "$PWD" --write-report build/reports/shared-features-delta-report.json'
REMOVAL_BLOCKERS=(
  "Pinned shared-features-spm source does not yet contain every carriedDeltas entry."
  "CI still runs STRICT_REQUIRED_PATCHES=1 bash scripts/spm-shared-features-fixes.sh after package resolution."
  "Native crypto package/modulemap contract reapply is still required for the pinned source."
)
REMOVAL_REQUIRED_ABSENT_MARKERS=(
  "STRICT_REQUIRED_PATCHES=1 bash scripts/spm-shared-features-fixes.sh"
  "scripts/deps/prepare-native-crypto-checkout.sh after package resolution"
  "scripts/deps/apply-native-crypto-package-contract.sh against a resolved checkout"
  "scripts/deps/apply-native-crypto-modulemap-contract.sh against a resolved checkout"
)

for index in "${!DELTA_IDS[@]}"; do
  require_pattern "$SPM_FIXES" "${DELTA_PATTERNS[$index]}" "shared-features carried delta ${DELTA_IDS[$index]} (${DELTA_LABELS[$index]})"
done

require_pattern "$SPM_FIXES" "STRICT_REQUIRED_PATCHES" "shared-features strict patch mode"
require_pattern "$SPM_FIXES" "REQUIRED_PATCH_COUNT" "shared-features required patch accounting"
require_pattern "$UPSTREAM_DELTA_DOC" "Exit condition for Milestone 3" "native crypto upstream delta exit condition"
require_pattern "$UPSTREAM_DELTA_DOC" "source already contains this delta" "native crypto upstream completion rule"
require_pattern "$UPSTREAM_DELTA_DOC" "export-native-crypto-upstream-delta.sh" "native crypto export handoff docs"
require_pattern "$STABILITY_DOC" "scripts/deps/audit-shared-features-delta-report.sh" "SSF stability delta-report audit docs"
require_pattern "$STABILITY_DOC" "build/reports/shared-features-delta-report.json" "SSF stability delta-report artifact docs"

REVISION=""
if [[ -f "$WORKSPACE_RESOLVED" ]]; then
  REVISION="$(extract_shared_features_revision "$WORKSPACE_RESOLVED")"
  [[ -n "$REVISION" ]] || record_failure "Could not extract shared-features-spm revision from $WORKSPACE_RESOLVED"
fi

write_report() {
  local report_file="$1"
  local report_dir
  report_dir="$(dirname "$report_file")"

  if ! mkdir -p "$report_dir" 2>/dev/null; then
    echo "[shared-features-delta][error] Failed to write shared-features delta report: cannot create $report_dir" >&2
    exit 1
  fi

  local tmp="${report_file}.tmp"
  {
    echo "{"
    echo "  \"schemaVersion\": 1,"
    echo "  \"sharedFeaturesRevision\": \"$(printf '%s' "$REVISION" | json_escape)\","
    echo "  \"mutatesResolvedCheckout\": true,"
    echo "  \"exitCondition\": \"Pinned shared-features-spm source contains all carried deltas and CI no longer runs checkout mutation scripts after package resolution.\","
    echo "  \"removalReadiness\": {"
    echo "    \"status\": \"$(printf '%s' "$REMOVAL_READINESS_STATUS" | json_escape)\","
    echo "    \"requiredAction\": \"$(printf '%s' "$REMOVAL_REQUIRED_ACTION" | json_escape)\","
    echo "    \"verificationCommand\": \"$(printf '%s' "$REMOVAL_VERIFICATION_COMMAND" | json_escape)\","
    echo "    \"blockers\": ["
    for index in "${!REMOVAL_BLOCKERS[@]}"; do
      local comma=","
      [[ "$index" == "$((${#REMOVAL_BLOCKERS[@]} - 1))" ]] && comma=""
      echo "      \"$(printf '%s' "${REMOVAL_BLOCKERS[$index]}" | json_escape)\"${comma}"
    done
    echo "    ],"
    echo "    \"requiredAbsentMarkersBeforeResolved\": ["
    for index in "${!REMOVAL_REQUIRED_ABSENT_MARKERS[@]}"; do
      local comma=","
      [[ "$index" == "$((${#REMOVAL_REQUIRED_ABSENT_MARKERS[@]} - 1))" ]] && comma=""
      echo "      \"$(printf '%s' "${REMOVAL_REQUIRED_ABSENT_MARKERS[$index]}" | json_escape)\"${comma}"
    done
    echo "    ]"
    echo "  },"
    echo "  \"nativeCryptoTemplates\": ["
    local template_paths=("$MODULEMAP_TEMPLATE" "$UMBRELLA_TEMPLATE" "$LINKER_TEMPLATE")
    local template_names=("IrohaCrypto.module.modulemap" "IrohaCrypto-umbrella.h" "IrohaCrypto.linker-settings.swiftfrag")
    for index in "${!template_paths[@]}"; do
      local comma=","
      [[ "$index" == "$((${#template_paths[@]} - 1))" ]] && comma=""
      echo "    { \"name\": \"${template_names[$index]}\", \"path\": \"$(printf '%s' "${template_paths[$index]#$ROOT/}" | json_escape)\", \"sha256\": \"$(sha256_file "${template_paths[$index]}")\" }${comma}"
    done
    echo "  ],"
    echo "  \"carriedDeltas\": ["
    for index in "${!DELTA_IDS[@]}"; do
      local comma=","
      [[ "$index" == "$((${#DELTA_IDS[@]} - 1))" ]] && comma=""
      echo "    { \"id\": \"${DELTA_IDS[$index]}\", \"label\": \"$(printf '%s' "${DELTA_LABELS[$index]}" | json_escape)\", \"evidence\": \"$(printf '%s' "${DELTA_PATTERNS[$index]}" | json_escape)\" }${comma}"
    done
    echo "  ]"
    echo "}"
  } > "$tmp" || {
    rm -f "$tmp"
    echo "[shared-features-delta][error] Failed to write shared-features delta report: $report_file" >&2
    exit 1
  }

  if ! mv "$tmp" "$report_file" 2>/dev/null; then
    rm -f "$tmp"
    echo "[shared-features-delta][error] Failed to write shared-features delta report: $report_file" >&2
    exit 1
  fi
}

if ((${#failures[@]} > 0)); then
  echo "[shared-features-delta][error] Shared-features delta audit failed:" >&2
  for failure in "${failures[@]}"; do
    echo "  - $failure" >&2
  done
  exit 1
fi

if [[ -n "$REPORT_FILE" ]]; then
  write_report "$REPORT_FILE"
fi

echo "[shared-features-delta] Audit passed: revision=${REVISION}, carriedDeltas=${#DELTA_IDS[@]}"
if [[ -n "$REPORT_FILE" ]]; then
  echo "[shared-features-delta] Wrote report: $REPORT_FILE"
fi
