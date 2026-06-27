#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit-shared-features-delta-report.sh"

fail() {
  echo "[shared-features-delta-test][error] $*" >&2
  exit 1
}

write_file() {
  local file="$1"
  shift
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$@" > "$file"
}

write_fixture() {
  local root="$1"
  mkdir -p \
    "$root/scripts/deps/templates" \
    "$root/fearless.xcworkspace/xcshareddata/swiftpm" \
    "$root/docs"

  write_file "$root/fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
    '{' \
    '  "pins" : [' \
    '    {' \
    '      "identity" : "shared-features-spm",' \
    '      "state" : {' \
    '        "revision" : "3ad0fe928333c9ac28972e3669ca733c6972f060"' \
    '      }' \
    '    }' \
    '  ]' \
    '}'

  write_file "$root/scripts/deps/templates/IrohaCrypto.module.modulemap" \
    'framework module IrohaCrypto {' \
    '    umbrella "."' \
    '    export *' \
    '    module * { export * }' \
    '}'

  write_file "$root/scripts/deps/templates/IrohaCrypto-umbrella.h" \
    '// Temporary umbrella header to satisfy IrohaCrypto module.modulemap' \
    '#import <Foundation/Foundation.h>'

  write_file "$root/scripts/deps/templates/IrohaCrypto.linker-settings.swiftfrag" \
    '            linkerSettings: [' \
    '                .linkedFramework("sorawallet")' \
    '            ]'

  write_file "$root/scripts/deps/export-native-crypto-upstream-delta.sh" \
    '#!/usr/bin/env bash' \
    'echo export-native-crypto-upstream-delta.sh'
  chmod +x "$root/scripts/deps/export-native-crypto-upstream-delta.sh"

  write_file "$root/docs/SSFNativeCryptoUpstreamDelta.md" \
    '# SSF Native Crypto Upstream Delta' \
    'Use export-native-crypto-upstream-delta.sh for upstream handoff.' \
    '## Exit condition for Milestone 3' \
    'Milestone 3 is complete when the pinned shared-features-spm source already contains this delta.'

  write_file "$root/docs/SSFStability.md" \
    '# SSF Stability' \
    'Run scripts/deps/audit-shared-features-delta-report.sh --write-report build/reports/shared-features-delta-report.json.' \
    'Review build/reports/shared-features-delta-report.json before release.'

  write_file "$root/scripts/spm-shared-features-fixes.sh" \
    '#!/usr/bin/env bash' \
    'STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"' \
    'REQUIRED_PATCH_COUNT=0' \
    'echo "https://github.com/soramitsu/web3-swift"' \
    'echo "BigInt.git"' \
    'echo "Updated SSFPolkaswap dependencies"' \
    'echo "SSFSoraKeystoreKeychain"' \
    'echo "EthereumPrivateKey(privateKey: Array"' \
    'echo "AddressFactory compatibility shims"' \
    'echo "__SSSE3__"' \
    'echo "libsr25519crust.a"' \
    'echo "PooledAssetInfo"' \
    'apply_native_crypto_contracts() { :; }' \
    'echo "No shared-features-spm checkout was available to patch"'
  chmod +x "$root/scripts/spm-shared-features-fixes.sh"
}

expect_failure() {
  local name="$1"
  local expected="$2"
  shift 2

  local output
  set +e
  output="$("$AUDIT_SCRIPT" "$@" 2>&1)"
  local status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "$output" >&2
    fail "$name unexpectedly passed"
  fi

  if [[ "$output" != *"$expected"* ]]; then
    echo "$output" >&2
    fail "$name did not report expected text: $expected"
  fi
}

expect_script_failure() {
  local name="$1"
  local expected="$2"
  local script="$3"
  shift 3

  local output
  set +e
  output="$("$script" "$@" 2>&1)"
  local status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "$output" >&2
    fail "$name unexpectedly passed"
  fi

  if [[ "$output" != *"$expected"* ]]; then
    echo "$output" >&2
    fail "$name did not report expected text: $expected"
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fixture="$tmp_dir/repo"
write_fixture "$fixture"

report="$tmp_dir/shared-features-delta-report.json"
"$AUDIT_SCRIPT" "$fixture" --write-report "$report" >/dev/null

node - "$report" <<'NODE'
const fs = require('fs');
const report = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

assert(report.schemaVersion === 1, 'schemaVersion must be 1');
assert(report.sharedFeaturesRevision === '3ad0fe928333c9ac28972e3669ca733c6972f060', 'revision must be reported');
assert(report.mutatesResolvedCheckout === true, 'checkout mutation status must be explicit');
assert(report.nativeCryptoTemplates.length === 3, 'native crypto template hashes must be reported');
assert(report.nativeCryptoTemplates.every((item) => /^[0-9a-f]{64}$/.test(item.sha256)), 'template hashes must be SHA-256 values');
assert(report.carriedDeltas.length === 11, 'all carried deltas must be reported');
assert(new Set(report.carriedDeltas.map((item) => item.id)).size === report.carriedDeltas.length, 'carried delta ids must be unique');
assert(report.carriedDeltas.some((item) => item.id === 'sorakeystore-runtime-namespace'), 'SoraKeystore delta must be reported');
assert(report.exitCondition.includes('CI no longer runs checkout mutation scripts'), 'exit condition must describe mutation removal');
assert(report.removalReadiness.status === 'blocked', 'removalReadiness status must remain blocked while checkout mutation is still required');
assert(report.removalReadiness.requiredAction.includes('carriedDeltas'), 'removalReadiness required action must reference carried deltas');
assert(report.removalReadiness.verificationCommand.includes('audit-shared-features-delta-report.sh'), 'removalReadiness verification command must name the audit');
assert(report.removalReadiness.blockers.length >= 3, 'removalReadiness blockers must be explicit');
assert(report.removalReadiness.requiredAbsentMarkersBeforeResolved.some((item) => item.includes('scripts/spm-shared-features-fixes.sh')), 'removalReadiness must name the mutation marker that has to disappear');
NODE

missing_sorakeystore="$tmp_dir/missing-sorakeystore"
cp -R "$fixture" "$missing_sorakeystore"
perl -0pi -e 's/SSFSoraKeystoreKeychain/SoraKeystoreKeychain/' "$missing_sorakeystore/scripts/spm-shared-features-fixes.sh"
expect_failure \
  "missing SoraKeystore delta" \
  "sorakeystore-runtime-namespace" \
  "$missing_sorakeystore"

missing_strict="$tmp_dir/missing-strict"
cp -R "$fixture" "$missing_strict"
perl -0pi -e 's/No shared-features-spm checkout was available to patch/no checkout marker removed/' "$missing_strict/scripts/spm-shared-features-fixes.sh"
expect_failure \
  "missing strict patch accounting" \
  "strict-required-patch-accounting" \
  "$missing_strict"

duplicate_delta_id_script="$tmp_dir/audit-duplicate-delta-id.sh"
cp "$AUDIT_SCRIPT" "$duplicate_delta_id_script"
chmod +x "$duplicate_delta_id_script"
perl -0pi -e 's/"strict-required-patch-accounting"/"native-crypto-contract-reapply"/' "$duplicate_delta_id_script"
expect_script_failure \
  "duplicate carried delta id" \
  "duplicate shared-features carried delta id: native-crypto-contract-reapply" \
  "$duplicate_delta_id_script" \
  "$fixture"

metadata_length_mismatch_script="$tmp_dir/audit-delta-metadata-length-mismatch.sh"
cp "$AUDIT_SCRIPT" "$metadata_length_mismatch_script"
chmod +x "$metadata_length_mismatch_script"
perl -0pi -e 's/"strict-required-patch-accounting"/"strict-required-patch-accounting"\n  "unexpected-extra-delta-id"/' "$metadata_length_mismatch_script"
expect_script_failure \
  "carried delta metadata length mismatch" \
  "carried delta metadata array length mismatch" \
  "$metadata_length_mismatch_script" \
  "$fixture"

missing_template="$tmp_dir/missing-template"
cp -R "$fixture" "$missing_template"
rm "$missing_template/scripts/deps/templates/IrohaCrypto.module.modulemap"
expect_failure \
  "missing native crypto template" \
  "IrohaCrypto modulemap template missing" \
  "$missing_template"

missing_exit_doc="$tmp_dir/missing-exit-doc"
cp -R "$fixture" "$missing_exit_doc"
perl -0pi -e 's/Exit condition for Milestone 3/Completion rule removed/' "$missing_exit_doc/docs/SSFNativeCryptoUpstreamDelta.md"
expect_failure \
  "missing upstream exit condition" \
  "native crypto upstream delta exit condition" \
  "$missing_exit_doc"

blocked_report_parent="$tmp_dir/blocked-report-parent"
printf locked > "$blocked_report_parent"
expect_failure \
  "unwritable report path" \
  "Failed to write shared-features delta report" \
  "$fixture" \
  --write-report "$blocked_report_parent/report.json"

echo "[shared-features-delta-test] all tests passed"
