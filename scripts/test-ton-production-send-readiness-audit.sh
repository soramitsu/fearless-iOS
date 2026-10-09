#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT_DIR/scripts/audit-ton-production-send-readiness.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ton-send-readiness-test.XXXXXX")"
CASES=0
EXPECTED_CASES=72

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

fail() {
  echo "[ton-send-readiness-test][error] $*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

make_fixture() {
  local fixture="$1"
  mkdir -p \
    "$fixture/config" \
    "$fixture/docs" \
    "$fixture/fearless/Modules/Send" \
    "$fixture/fearless/Common/Services/ChainRegistry" \
    "$fixture/fearless/Common/Model" \
    "$fixture/scripts/ci" \
    "$fixture/.github/workflows"
  cp "$ROOT_DIR/config/ton-production-send-readiness.json" "$fixture/config/"
  cp "$ROOT_DIR/docs/ton-production-send-readiness.md" "$fixture/docs/"
  cp "$ROOT_DIR/docs/release-checklist.md" "$fixture/docs/"
  cp "$ROOT_DIR/fearless/Modules/Send/SendDependencyContainer.swift" "$fixture/fearless/Modules/Send/"
  cp "$ROOT_DIR/fearless/Common/Services/ChainRegistry/ChainRegistry.swift" "$fixture/fearless/Common/Services/ChainRegistry/"
  cp "$ROOT_DIR/fearless/Common/Model/TonTransferTransactionBuilder.swift" "$fixture/fearless/Common/Model/"
  cp "$ROOT_DIR/fearless/Common/Model/TonSendService.swift" "$fixture/fearless/Common/Model/"
  cp "$ROOT_DIR/scripts/ci/run-pr.sh" "$fixture/scripts/ci/"
  cp "$ROOT_DIR/.github/workflows/codecov.yml" "$fixture/.github/workflows/"
}

new_fixture() {
  local name="$1"
  local fixture="$TMP_DIR/$name"
  make_fixture "$fixture"
  printf '%s\n' "$fixture"
}

set_json() {
  local manifest="$1"
  local field_path="$2"
  local json_value="$3"
  node - "$manifest" "$field_path" "$json_value" <<'NODE'
const fs = require('node:fs');
const [path, fieldPath, encoded] = process.argv.slice(2);
const value = JSON.parse(encoded);
const document = JSON.parse(fs.readFileSync(path, 'utf8'));
const segments = fieldPath.split('.');
let cursor = document;
for (const segment of segments.slice(0, -1)) cursor = cursor[segment];
cursor[segments.at(-1)] = value;
fs.writeFileSync(path, `${JSON.stringify(document, null, 2)}\n`);
NODE
}

mutate_swift_decoy() {
  local file="$1"
  local scenario="$2"
  node - "$file" "$scenario" <<'NODE'
const fs = require('node:fs');
const [path, scenario] = process.argv.slice(2);
const policy = 'static let production = TonProductionSendReleasePolicy(isEnabled: false)';
const origin = 'static let canonicalAuthenticatedOrigin = URL(string: "https://tonapi.io")!';
const allowlist = 'static let reviewedProductionSendOrigins = [canonicalAuthenticatedOrigin]';
const enabledPolicy = 'static let production = TonProductionSendReleasePolicy(isEnabled: true)';
const evilOrigin = 'static let canonicalAuthenticatedOrigin = URL(string: "https://evil.example")!';
const expandedAllowlist = 'static let reviewedProductionSendOrigins = [canonicalAuthenticatedOrigin, URL(string: "https://evil.example")!]';

const mutations = {
  'policy-multiline-string': [policy, `let disabledPolicyDecoy = """
        ${policy}
        """
    ${enabledPolicy}`],
  'policy-raw-string': [policy, `let disabledPolicyDecoy = #"${policy}"#
    ${enabledPolicy}`],
  'policy-raw-multiline-string': [policy, `let disabledPolicyDecoy = #"""
        ${policy}
        """#
    ${enabledPolicy}`],
  'policy-nested-comment': [policy, `/* outer disabled-policy decoy
       /* nested decoy */
       ${policy}
    */
    ${enabledPolicy}`],
  'policy-inactive-false': [policy, `#if false
        ${policy}
    #else
        ${enabledPolicy}
    #endif`],
  'policy-inactive-debug': [policy, `#if DEBUG
        ${policy}
    #else
        ${enabledPolicy}
    #endif`],
  'policy-unterminated-raw-string': [policy, `let disabledPolicyDecoy = #"${policy}
    ${enabledPolicy}`],
  'origin-multiline-string': [origin, `let authenticatedOriginDecoy = """
        ${origin}
        """
    ${evilOrigin}`],
  'origin-raw-string': [origin, `let authenticatedOriginDecoy = #"${origin}"#
    ${evilOrigin}`],
  'origin-raw-multiline-string': [origin, `let authenticatedOriginDecoy = ##"""
        ${origin}
        """##
    ${evilOrigin}`],
  'origin-nested-comment': [origin, `/* outer authenticated-origin decoy
       /* nested decoy */
       ${origin}
    */
    ${evilOrigin}`],
  'origin-inactive-false': [origin, `#if false
        ${origin}
    #else
        ${evilOrigin}
    #endif`],
  'origin-unterminated-nested-comment': [origin, `/* outer authenticated-origin decoy
       /* nested decoy */
       ${origin}
    ${evilOrigin}`],
  'allowlist-raw-string': [allowlist, `let reviewedAllowlistDecoy = #"${allowlist}"#
    ${expandedAllowlist}`]
};

const mutation = mutations[scenario];
if (!mutation) throw new Error(`unknown Swift decoy scenario: ${scenario}`);
const [needle, replacement] = mutation;
const source = fs.readFileSync(path, 'utf8');
const first = source.indexOf(needle);
if (first === -1) throw new Error(`Swift mutation marker is missing for ${scenario}`);
if (source.indexOf(needle, first + needle.length) !== -1) {
  throw new Error(`Swift mutation marker is ambiguous for ${scenario}`);
}
fs.writeFileSync(path, source.slice(0, first) + replacement + source.slice(first + needle.length));
NODE
}

expect_failure() {
  local label="$1"
  local fixture="$2"
  local expected="$3"
  local digest output status
  digest="$(sha256_file "$fixture/config/ton-production-send-readiness.json")"
  status=0
  output="$(
    TON_SEND_AUDIT_ROOT="$fixture" \
    TON_SEND_AUDIT_EXPECTED_MANIFEST_SHA256="$digest" \
      bash "$AUDIT" 2>&1
  )" || status=$?
  [[ "$status" -ne 0 ]] || fail "$label unexpectedly passed"
  grep -Fq -- "$expected" <<<"$output" ||
    fail "$label failed for the wrong reason; expected '$expected', got: $output"
  CASES=$((CASES + 1))
  echo "[ton-send-readiness-test] rejected $label"
}

expect_failure_with_digest() {
  local label="$1"
  local fixture="$2"
  local digest="$3"
  local expected="$4"
  local output status=0
  output="$(
    TON_SEND_AUDIT_ROOT="$fixture" \
    TON_SEND_AUDIT_EXPECTED_MANIFEST_SHA256="$digest" \
      bash "$AUDIT" 2>&1
  )" || status=$?
  [[ "$status" -ne 0 ]] || fail "$label unexpectedly passed"
  grep -Fq -- "$expected" <<<"$output" ||
    fail "$label failed for the wrong reason; expected '$expected', got: $output"
  CASES=$((CASES + 1))
  echo "[ton-send-readiness-test] rejected $label"
}

baseline="$(new_fixture baseline)"
TON_SEND_AUDIT_ROOT="$baseline" bash "$AUDIT" >/dev/null ||
  fail "valid blocked baseline was rejected"
CASES=$((CASES + 1))
echo "[ton-send-readiness-test] accepted valid blocked baseline"

fixture="$(new_fixture release-enabled)"
set_json "$fixture/config/ton-production-send-readiness.json" releaseEnabled true
expect_failure "release-enabled manifest" "$fixture" "releaseEnabled must remain false"

fixture="$(new_fixture ready-status)"
set_json "$fixture/config/ton-production-send-readiness.json" status '"ready"'
expect_failure "ready status claim" "$fixture" "status must remain blocked"

fixture="$(new_fixture runtime-initializer-enabled)"
set_json "$fixture/config/ton-production-send-readiness.json" runtimeGuard.productionInitializer '"isEnabled: true"'
expect_failure "enabled manifest runtime initializer" "$fixture" "production initializer must remain disabled"

fixture="$(new_fixture runtime-override)"
set_json "$fixture/config/ton-production-send-readiness.json" runtimeGuard.runtimeOverrideAllowed true
expect_failure "runtime override claim" "$fixture" "runtime override must remain forbidden"

fixture="$(new_fixture parity-claim)"
set_json "$fixture/config/ton-production-send-readiness.json" feeEvidence.tonApiParityEvidence '"fixture-only"'
expect_failure "unreviewed fee-parity claim" "$fixture" "independent TonAPI fee parity evidence must remain missing until review"

fixture="$(new_fixture replacement-claim)"
set_json "$fixture/config/ton-production-send-readiness.json" feeEvidence.reviewedAttestedReplacement '"local-tvm"'
expect_failure "unattested local replacement claim" "$fixture" "a local replacement must not be claimed without reviewed attestation"

fixture="$(new_fixture fee-criterion)"
set_json "$fixture/config/ton-production-send-readiness.json" feeEvidence.criterionSatisfied true
expect_failure "fee criterion claim" "$fixture" "fee evidence criterion must remain unsatisfied"

fixture="$(new_fixture unsigned-endpoint)"
set_json "$fixture/config/ton-production-send-readiness.json" feeEvidence.unsignedEndpoint '"/v2/wallet/emulate"'
expect_failure "unsigned endpoint drift" "$fixture" "unsigned emulation endpoint drifted"

fixture="$(new_fixture signed-endpoint)"
set_json "$fixture/config/ton-production-send-readiness.json" feeEvidence.signedEndpoint '"/v2/traces/emulate"'
expect_failure "signed endpoint drift" "$fixture" "signed emulation endpoint drifted"

fixture="$(new_fixture wallet-version)"
set_json "$fixture/config/ton-production-send-readiness.json" feeEvidence.walletVersion '"Wallet V5R1"'
expect_failure "wallet version drift" "$fixture" "fee evidence wallet version drifted"

fixture="$(new_fixture credential-origin)"
set_json "$fixture/config/ton-production-send-readiness.json" endpointCredentialEvidence.requiredOrigin '"https://evil.example"'
expect_failure "authenticated origin drift" "$fixture" "required authenticated origin drifted"

fixture="$(new_fixture credential-provisioned)"
set_json "$fixture/config/ton-production-send-readiness.json" endpointCredentialEvidence.releaseProvisioningAttestation '"provisioned"'
expect_failure "unreviewed credential provisioning claim" "$fixture" "release credential provisioning must remain unattested"

fixture="$(new_fixture registry-attested)"
set_json "$fixture/config/ton-production-send-readiness.json" endpointCredentialEvidence.registryOriginAttestation '"reviewed"'
expect_failure "unreviewed registry-origin claim" "$fixture" "registry origin must remain unattested"

fixture="$(new_fixture credential-criterion)"
set_json "$fixture/config/ton-production-send-readiness.json" endpointCredentialEvidence.criterionSatisfied true
expect_failure "credential criterion claim" "$fixture" "endpoint credential criterion must remain unsatisfied"

fixture="$(new_fixture funded-bundle)"
set_json "$fixture/config/ton-production-send-readiness.json" fundedMainnetEvidence.evidenceBundle '"screenshot.zip"'
expect_failure "fixture funded bundle claim" "$fixture" "funded mainnet evidence must remain missing"

fixture="$(new_fixture funded-hash)"
set_json "$fixture/config/ton-production-send-readiness.json" fundedMainnetEvidence.transactionHash '"0000000000000000000000000000000000000000000000000000000000000000"'
expect_failure "placeholder funded transaction hash" "$fixture" "no funded-mainnet transaction hash may be claimed"

fixture="$(new_fixture funded-stages)"
set_json "$fixture/config/ton-production-send-readiness.json" fundedMainnetEvidence.requiredStages '["broadcast"]'
expect_failure "incomplete funded evidence stages" "$fixture" "funded mainnet required stages drifted"

fixture="$(new_fixture funded-criterion)"
set_json "$fixture/config/ton-production-send-readiness.json" fundedMainnetEvidence.criterionSatisfied true
expect_failure "funded criterion claim" "$fixture" "funded mainnet criterion must remain unsatisfied"

fixture="$(new_fixture finalized-procedure)"
set_json "$fixture/config/ton-production-send-readiness.json" expiredIntentRecoveryEvidence.finalizedChainAbsenceProcedure '"draft"'
expect_failure "unreviewed finalized-absence procedure claim" "$fixture" "finalized-chain absence procedure must remain missing"

fixture="$(new_fixture quarantine-procedure)"
set_json "$fixture/config/ton-production-send-readiness.json" expiredIntentRecoveryEvidence.auditedQuarantineProcedure '"draft"'
expect_failure "unreviewed quarantine procedure claim" "$fixture" "audited quarantine procedure must remain missing"

fixture="$(new_fixture selected-procedure)"
set_json "$fixture/config/ton-production-send-readiness.json" expiredIntentRecoveryEvidence.selectedProcedure '"quarantine"'
expect_failure "unreviewed recovery selection" "$fixture" "no unreviewed expired-intent procedure may be selected"

fixture="$(new_fixture sender-unblock)"
set_json "$fixture/config/ton-production-send-readiness.json" expiredIntentRecoveryEvidence.senderUnblockAllowed true
expect_failure "sender unblock claim" "$fixture" "sender unblock must remain forbidden"

fixture="$(new_fixture recovery-criterion)"
set_json "$fixture/config/ton-production-send-readiness.json" expiredIntentRecoveryEvidence.criterionSatisfied true
expect_failure "recovery criterion claim" "$fixture" "expired-intent recovery criterion must remain unsatisfied"

fixture="$(new_fixture evidence-bundle-id)"
set_json "$fixture/config/ton-production-send-readiness.json" releaseEvidenceBundle.immutableBundleId '"unreviewed"'
expect_failure "unreviewed immutable bundle claim" "$fixture" "immutable evidence bundle ID must remain absent"

fixture="$(new_fixture evidence-reviewers)"
set_json "$fixture/config/ton-production-send-readiness.json" releaseEvidenceBundle.reviewers '["self"]'
expect_failure "self-reviewed evidence claim" "$fixture" "release evidence reviewers drifted"

fixture="$(new_fixture all-criteria)"
set_json "$fixture/config/ton-production-send-readiness.json" releaseEvidenceBundle.allCriteriaSatisfied true
expect_failure "all-criteria claim" "$fixture" "release evidence bundle must remain incomplete"

fixture="$(new_fixture blocker-code)"
set_json "$fixture/config/ton-production-send-readiness.json" blocker.code '"ready"'
expect_failure "blocker-code removal" "$fixture" "blocker code drifted"

fixture="$(new_fixture exit-criteria)"
set_json "$fixture/config/ton-production-send-readiness.json" exitCriteria '[]'
expect_failure "removed exit criteria" "$fixture" "exit criteria drifted"

fixture="$(new_fixture unknown-key)"
set_json "$fixture/config/ton-production-send-readiness.json" unexpected '"decoy"'
expect_failure "unknown manifest key" "$fixture" "top-level manifest keys drifted"

fixture="$(new_fixture invalid-json)"
printf '{invalid\n' > "$fixture/config/ton-production-send-readiness.json"
expect_failure "invalid JSON" "$fixture" "invalid readiness JSON"

fixture="$(new_fixture oversized-json)"
dd if=/dev/zero bs=33000 count=1 2>/dev/null | tr '\0' ' ' >> "$fixture/config/ton-production-send-readiness.json"
expect_failure "oversized manifest" "$fixture" "readiness manifest exceeds 32 KiB"

fixture="$(new_fixture digest-mismatch)"
set_json "$fixture/config/ton-production-send-readiness.json" assessedAt '"2026-07-17"'
expect_failure_with_digest "unpinned manifest mutation" "$fixture" \
  "$(sha256_file "$ROOT_DIR/config/ton-production-send-readiness.json")" \
  "readiness manifest digest mismatch"

fixture="$(new_fixture invalid-expected-digest)"
expect_failure_with_digest "invalid expected digest" "$fixture" "NOT-A-DIGEST" \
  "expected manifest digest must be exactly 64 lowercase hexadecimal characters"

fixture="$(new_fixture manifest-symlink)"
rm "$fixture/config/ton-production-send-readiness.json"
ln -s ../docs/ton-production-send-readiness.md "$fixture/config/ton-production-send-readiness.json"
expect_failure_with_digest "symlinked manifest" "$fixture" \
  "$(printf '0%.0s' {1..64})" \
  "required regular file is missing or is a symlink"

fixture="$(new_fixture document-symlink)"
rm "$fixture/docs/ton-production-send-readiness.md"
ln -s release-checklist.md "$fixture/docs/ton-production-send-readiness.md"
expect_failure "symlinked readiness document" "$fixture" "required regular file is missing or is a symlink"

fixture="$(new_fixture document-status)"
perl -0pi -e 's/Status: \*\*BLOCKED \/ fail closed\*\*\./Status: READY./' "$fixture/docs/ton-production-send-readiness.md"
expect_failure "removed blocked document status" "$fixture" "blocked TON readiness status"

fixture="$(new_fixture document-replacement)"
perl -0pi -e 's/reviewed and attested local-TVM or quote mechanism/local fallback/' "$fixture/docs/ton-production-send-readiness.md"
expect_failure "weakened replacement documentation" "$fixture" "reviewed attested replacement requirement"

fixture="$(new_fixture checklist-command)"
perl -0pi -e 's/bash \.\/scripts\/test-ton-production-send-readiness-audit\.sh && bash \.\/scripts\/audit-ton-production-send-readiness\.sh/echo skipped-ton-gate/' "$fixture/docs/release-checklist.md"
expect_failure "removed release-checklist command" "$fixture" "release-checklist TON readiness command"

fixture="$(new_fixture checklist-parity)"
perl -0pi -e 's/exact fee parity with the corresponding signed Wallet V4R2/fees are assumed to match/' "$fixture/docs/release-checklist.md"
expect_failure "weakened checklist fee parity" "$fixture" "release-checklist exact fee parity requirement"

fixture="$(new_fixture checklist-finality)"
perl -0pi -e 's/finalized-chain absence proof or explicit audited quarantine/local timeout/' "$fixture/docs/release-checklist.md"
expect_failure "weakened checklist recovery" "$fixture" "release-checklist finalized-absence or quarantine requirement"

fixture="$(new_fixture run-pr-self-test)"
perl -0pi -e 's/bash "\$WORKSPACE_DIR\/scripts\/test-ton-production-send-readiness-audit\.sh"/echo removed-ton-self-test/' "$fixture/scripts/ci/run-pr.sh"
expect_failure "removed PR CI self-test" "$fixture" "PR CI TON readiness adversarial self-test"

fixture="$(new_fixture run-pr-audit)"
perl -0pi -e 's/bash "\$WORKSPACE_DIR\/scripts\/audit-ton-production-send-readiness\.sh"/echo removed-ton-audit/' "$fixture/scripts/ci/run-pr.sh"
expect_failure "removed PR CI audit" "$fixture" "PR CI TON readiness audit"

fixture="$(new_fixture workflow-self-test)"
perl -0pi -e 's/bash \.\/scripts\/test-ton-production-send-readiness-audit\.sh/echo removed-ton-self-test/' "$fixture/.github/workflows/codecov.yml"
expect_failure "removed GitHub CI self-test" "$fixture" "GitHub CI TON readiness adversarial self-test"

fixture="$(new_fixture workflow-audit)"
perl -0pi -e 's/bash \.\/scripts\/audit-ton-production-send-readiness\.sh/echo removed-ton-audit/' "$fixture/.github/workflows/codecov.yml"
expect_failure "removed GitHub CI audit" "$fixture" "GitHub CI TON readiness audit"

fixture="$(new_fixture production-policy-enabled)"
perl -0pi -e 's/static let production = TonProductionSendReleasePolicy\(isEnabled: false\)/static let production = TonProductionSendReleasePolicy(isEnabled: true)/' "$fixture/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "enabled Swift production policy" "$fixture" "TON production policy must have exactly one active false initializer"

fixture="$(new_fixture public-policy-initializer)"
perl -0pi -e 's/private init\(isEnabled: Bool\)/init(isEnabled: Bool)/' "$fixture/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "public Swift policy initializer" "$fixture" "TON release-policy initializer must remain private"

fixture="$(new_fixture escaped-debug-policy)"
perl -0pi -e 's/#if DEBUG\n        static let enabledForTests/#if RELEASE\n        static let enabledForTests/' "$fixture/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "test policy outside DEBUG" "$fixture" "TON enabledForTests policy escaped the DEBUG block"

fixture="$(new_fixture comment-decoy-policy)"
perl -0pi -e 's/static let production = TonProductionSendReleasePolicy\(isEnabled: false\)/\/\/ static let production = TonProductionSendReleasePolicy(isEnabled: false)\n    static let production = TonProductionSendReleasePolicy(isEnabled: true)/' "$fixture/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "comment-decoy disabled policy" "$fixture" "TON production policy must have exactly one active false initializer"

fixture="$(new_fixture multiline-string-policy-decoy)"
mutate_swift_decoy "$fixture/fearless/Modules/Send/SendDependencyContainer.swift" policy-multiline-string
expect_failure "multiline-string disabled-policy decoy" "$fixture" "TON production policy must have exactly one active false initializer"

fixture="$(new_fixture raw-string-policy-decoy)"
mutate_swift_decoy "$fixture/fearless/Modules/Send/SendDependencyContainer.swift" policy-raw-string
expect_failure "raw-string disabled-policy decoy" "$fixture" "TON production policy must have exactly one active false initializer"

fixture="$(new_fixture raw-multiline-policy-decoy)"
mutate_swift_decoy "$fixture/fearless/Modules/Send/SendDependencyContainer.swift" policy-raw-multiline-string
expect_failure "raw-multiline-string disabled-policy decoy" "$fixture" "TON production policy must have exactly one active false initializer"

fixture="$(new_fixture nested-comment-policy-decoy)"
mutate_swift_decoy "$fixture/fearless/Modules/Send/SendDependencyContainer.swift" policy-nested-comment
expect_failure "nested-comment disabled-policy decoy" "$fixture" "TON production policy must have exactly one active false initializer"

fixture="$(new_fixture inactive-false-policy-decoy)"
mutate_swift_decoy "$fixture/fearless/Modules/Send/SendDependencyContainer.swift" policy-inactive-false
expect_failure "inactive-false disabled-policy decoy" "$fixture" "TON production policy must have exactly one active false initializer"

fixture="$(new_fixture inactive-debug-policy-decoy)"
mutate_swift_decoy "$fixture/fearless/Modules/Send/SendDependencyContainer.swift" policy-inactive-debug
expect_failure "inactive-DEBUG disabled-policy decoy" "$fixture" "TON production policy must have exactly one active false initializer"

fixture="$(new_fixture unterminated-raw-policy-decoy)"
mutate_swift_decoy "$fixture/fearless/Modules/Send/SendDependencyContainer.swift" policy-unterminated-raw-string
expect_failure "unterminated raw policy string" "$fixture" "unterminated Swift string literal"

fixture="$(new_fixture canonical-origin-source)"
perl -0pi -e 's#https://tonapi\.io#https://evil.example#' "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "source canonical-origin drift" "$fixture" "canonical authenticated TonAPI origin drifted"

fixture="$(new_fixture multiline-string-origin-decoy)"
mutate_swift_decoy "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift" origin-multiline-string
expect_failure "multiline-string authenticated-origin decoy" "$fixture" "canonical authenticated TonAPI origin drifted"

fixture="$(new_fixture raw-string-origin-decoy)"
mutate_swift_decoy "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift" origin-raw-string
expect_failure "raw-string authenticated-origin decoy" "$fixture" "canonical authenticated TonAPI origin drifted"

fixture="$(new_fixture raw-multiline-origin-decoy)"
mutate_swift_decoy "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift" origin-raw-multiline-string
expect_failure "raw-multiline-string authenticated-origin decoy" "$fixture" "canonical authenticated TonAPI origin drifted"

fixture="$(new_fixture nested-comment-origin-decoy)"
mutate_swift_decoy "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift" origin-nested-comment
expect_failure "nested-comment authenticated-origin decoy" "$fixture" "canonical authenticated TonAPI origin drifted"

fixture="$(new_fixture inactive-origin-decoy)"
mutate_swift_decoy "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift" origin-inactive-false
expect_failure "inactive-branch authenticated-origin decoy" "$fixture" "canonical authenticated TonAPI origin drifted"

fixture="$(new_fixture unterminated-origin-comment)"
mutate_swift_decoy "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift" origin-unterminated-nested-comment
expect_failure "unterminated nested origin comment" "$fixture" "unterminated nested block comment"

fixture="$(new_fixture expanded-origin-allowlist)"
perl -0pi -e 's/\[canonicalAuthenticatedOrigin\]/[canonicalAuthenticatedOrigin, URL(string: "https:\/\/evil.example")!]/' "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "expanded send-origin allowlist" "$fixture" "reviewed TonAPI send-origin allowlist drifted"

fixture="$(new_fixture raw-string-allowlist-decoy)"
mutate_swift_decoy "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift" allowlist-raw-string
expect_failure "raw-string reviewed-allowlist decoy" "$fixture" "reviewed TonAPI send-origin allowlist drifted"

fixture="$(new_fixture credential-length)"
perl -0pi -e 's/bytes\.count <= 4096/bytes.count <= 8192/' "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "relaxed credential length" "$fixture" "TonAPI release credential validation contract drifted"

fixture="$(new_fixture credential-ascii)"
perl -0pi -e 's/\(0x21 \.\.\. 0x7E\)/\(0x20 ... 0x7E\)/' "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "credential whitespace acceptance" "$fixture" "TonAPI release credential validation contract drifted"

fixture="$(new_fixture credential-origin-binding)"
perl -0pi -e 's/usesAuthorization && Self\.isReviewedProductionSendServerURL\(tonAPIURL\)/Self.isReviewedProductionSendServerURL(tonAPIURL)/' "$fixture/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "missing credential/origin binding" "$fixture" "TonAPI signed-operation credential/origin binding drifted"

fixture="$(new_fixture unsigned-signature-check)"
perl -0pi -e 's/ignore_signature_check: true/ignore_signature_check: false/' "$fixture/fearless/Common/Model/TonSendService.swift"
expect_failure "unsigned emulation signature-bypass drift" "$fixture" "TonAPI unsigned signature-bypass emulation seam drifted"

fixture="$(new_fixture signed-endpoint-guard)"
perl -0pi -e 's/(func emulateSigned\([\s\S]{0,300}?)try requireTrustedSignedOperationEndpoint\(\)/$1/' "$fixture/fearless/Common/Model/TonSendService.swift"
expect_failure "removed signed-emulation endpoint guard" "$fixture" "TonAPI signed Wallet V4R2 emulation seam drifted"

fixture="$(new_fixture signed-fee-drift)"
perl -0pi -e 's/emulation\.totalFeeNanotons != feeQuote\.feeNanotons/emulation.totalFeeNanotons == feeQuote.feeNanotons/' "$fixture/fearless/Common/Model/TonSendService.swift"
expect_failure "reversed signed fee-drift guard" "$fixture" "signed-emulation fee drift must fail closed"

fixture="$(new_fixture unsigned-builder)"
perl -0pi -e 's/static func buildForFeeEstimation\(/static func buildAdvisoryEstimate\(/' "$fixture/fearless/Common/Model/TonTransferTransactionBuilder.swift"
expect_failure "removed unsigned Wallet V4R2 builder" "$fixture" "Wallet V4R2 unsigned fee-estimation builder drifted"

if ((CASES != EXPECTED_CASES)); then
  fail "executed $CASES fixtures; expected exactly $EXPECTED_CASES"
fi
echo "[ton-send-readiness-test] all $CASES blocked-contract and adversarial fixtures passed"
