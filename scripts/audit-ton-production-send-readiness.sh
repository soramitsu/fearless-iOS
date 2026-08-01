#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${TON_SEND_AUDIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="$ROOT_DIR/config/ton-production-send-readiness.json"
DOC="$ROOT_DIR/docs/ton-production-send-readiness.md"
RELEASE_CHECKLIST="$ROOT_DIR/docs/release-checklist.md"
SEND_CONTAINER="$ROOT_DIR/fearless/Modules/Send/SendDependencyContainer.swift"
CHAIN_REGISTRY="$ROOT_DIR/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
TON_BUILDER="$ROOT_DIR/fearless/Common/Model/TonTransferTransactionBuilder.swift"
TON_SERVICE="$ROOT_DIR/fearless/Common/Model/TonSendService.swift"
RUN_PR="$ROOT_DIR/scripts/ci/run-pr.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/codecov.yml"
EXPECTED_MANIFEST_SHA256="${TON_SEND_AUDIT_EXPECTED_MANIFEST_SHA256:-5673b0df8a293df3961761db4f7c3a08363d3eb8a84ebdb49f1d2f4822209286}"

fail() {
  echo "[ton-send-readiness][ios][error] $*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

require_file() {
  local path="$1"
  [[ -f "$path" && ! -L "$path" ]] ||
    fail "required regular file is missing or is a symlink: ${path#"$ROOT_DIR/"}"
}

require_fixed() {
  local path="$1"
  local marker="$2"
  local label="$3"
  grep -Fq -- "$marker" "$path" || fail "$label is missing from ${path#"$ROOT_DIR/"}"
}

require_active_line() {
  local path="$1"
  local expected="$2"
  local label="$3"
  awk -v expected="$expected" '
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      if (line == expected) found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$path" || fail "$label is missing from ${path#"$ROOT_DIR/"}"
}

for path in \
  "$MANIFEST" "$DOC" "$RELEASE_CHECKLIST" "$SEND_CONTAINER" \
  "$CHAIN_REGISTRY" "$TON_BUILDER" "$TON_SERVICE" "$RUN_PR" "$WORKFLOW"; do
  require_file "$path"
done

manifest_bytes="$(wc -c < "$MANIFEST" | tr -d '[:space:]')"
[[ "$manifest_bytes" =~ ^[0-9]+$ && "$manifest_bytes" -le 32768 ]] ||
  fail "readiness manifest exceeds 32 KiB"
[[ "$EXPECTED_MANIFEST_SHA256" =~ ^[0-9a-f]{64}$ ]] ||
  fail "expected manifest digest must be exactly 64 lowercase hexadecimal characters"
actual_manifest_sha256="$(sha256_file "$MANIFEST")"
[[ "$actual_manifest_sha256" == "$EXPECTED_MANIFEST_SHA256" ]] ||
  fail "readiness manifest digest mismatch: expected $EXPECTED_MANIFEST_SHA256, got $actual_manifest_sha256"

node - "$MANIFEST" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
let manifest;
try {
  manifest = JSON.parse(fs.readFileSync(path, 'utf8'));
} catch (error) {
  console.error(`[ton-send-readiness][ios][error] invalid readiness JSON: ${error.message}`);
  process.exit(1);
}

function fail(message) {
  console.error(`[ton-send-readiness][ios][error] ${message}`);
  process.exit(1);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function exactKeys(value, expected, label) {
  assert(value && typeof value === 'object' && !Array.isArray(value), `${label} must be an object`);
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  assert(JSON.stringify(actual) === JSON.stringify(wanted), `${label} keys drifted`);
}

function exactArray(value, expected, label) {
  assert(Array.isArray(value), `${label} must be an array`);
  assert(JSON.stringify(value) === JSON.stringify(expected), `${label} drifted`);
  assert(new Set(value).size === value.length, `${label} must not contain duplicates`);
}

exactKeys(manifest, [
  'schemaVersion', 'platform', 'chain', 'assessedAt', 'status',
  'releaseEnabled', 'runtimeGuard', 'feeEvidence',
  'endpointCredentialEvidence', 'fundedMainnetEvidence',
  'expiredIntentRecoveryEvidence', 'releaseEvidenceBundle', 'blocker',
  'exitCriteria'
], 'top-level manifest');
assert(manifest.schemaVersion === 1, 'schemaVersion must be 1');
assert(manifest.platform === 'ios', 'platform must be ios');
assert(manifest.chain === 'ton-mainnet', 'chain must be ton-mainnet');
assert(manifest.assessedAt === '2026-07-16', 'assessment date drifted');
assert(manifest.status === 'blocked', 'status must remain blocked');
assert(manifest.releaseEnabled === false, 'releaseEnabled must remain false');

exactKeys(manifest.runtimeGuard, [
  'policyType', 'productionInitializer', 'runtimeOverrideAllowed',
  'debugTestOverrideOnly'
], 'runtimeGuard');
assert(manifest.runtimeGuard.policyType === 'TonProductionSendReleasePolicy', 'runtime policy type drifted');
assert(manifest.runtimeGuard.productionInitializer === 'isEnabled: false', 'production initializer must remain disabled');
assert(manifest.runtimeGuard.runtimeOverrideAllowed === false, 'runtime override must remain forbidden');
assert(manifest.runtimeGuard.debugTestOverrideOnly === true, 'enablement must remain DEBUG-test-only');

const fee = manifest.feeEvidence;
exactKeys(fee, [
  'walletVersion', 'activeMechanism', 'unsignedEndpoint', 'signedEndpoint',
  'requiredComparison', 'tonApiParityEvidence',
  'reviewedAttestedReplacement', 'criterionSatisfied'
], 'feeEvidence');
assert(fee.walletVersion === 'Wallet V4R2', 'fee evidence wallet version drifted');
assert(fee.activeMechanism === 'tonapi-unsigned-ignore-signature-check-plus-signed-emulation', 'fee mechanism drifted');
assert(fee.unsignedEndpoint === '/v2/traces/emulate?ignore_signature_check=true', 'unsigned emulation endpoint drifted');
assert(fee.signedEndpoint === '/v2/wallet/emulate', 'signed emulation endpoint drifted');
assert(fee.requiredComparison === 'exact-total-fee-nanotons-for-identical-wallet-v4r2-template', 'fee parity comparison drifted');
assert(fee.tonApiParityEvidence === 'missing', 'independent TonAPI fee parity evidence must remain missing until review');
assert(fee.reviewedAttestedReplacement === 'not-provided', 'a local replacement must not be claimed without reviewed attestation');
assert(fee.criterionSatisfied === false, 'fee evidence criterion must remain unsatisfied');

const credential = manifest.endpointCredentialEvidence;
exactKeys(credential, [
  'requiredOrigin', 'credentialContract', 'releaseProvisioningAttestation',
  'registryOriginAttestation', 'credentialExposureReview',
  'criterionSatisfied'
], 'endpointCredentialEvidence');
assert(credential.requiredOrigin === 'https://tonapi.io', 'required authenticated origin drifted');
assert(credential.credentialContract === 'nonempty-visible-ascii-maximum-4096-bytes', 'credential contract drifted');
assert(credential.releaseProvisioningAttestation === 'missing', 'release credential provisioning must remain unattested');
assert(credential.registryOriginAttestation === 'missing', 'registry origin must remain unattested');
assert(credential.credentialExposureReview === 'missing', 'credential exposure review must remain missing');
assert(credential.criterionSatisfied === false, 'endpoint credential criterion must remain unsatisfied');

const funded = manifest.fundedMainnetEvidence;
exactKeys(funded, [
  'walletVersion', 'requiredStages', 'evidenceBundle', 'transactionHash',
  'criterionSatisfied'
], 'fundedMainnetEvidence');
assert(funded.walletVersion === 'Wallet V4R2', 'funded evidence wallet version drifted');
exactArray(funded.requiredStages, [
  'unsigned-emulation',
  'signed-emulation',
  'broadcast',
  'on-chain-reconciliation',
  'exact-fee-verification',
  'recipient-credit-verification'
], 'funded mainnet required stages');
assert(funded.evidenceBundle === 'missing', 'funded mainnet evidence must remain missing');
assert(funded.transactionHash === null, 'no funded-mainnet transaction hash may be claimed');
assert(funded.criterionSatisfied === false, 'funded mainnet criterion must remain unsatisfied');

const recovery = manifest.expiredIntentRecoveryEvidence;
exactKeys(recovery, [
  'requiredPolicy', 'currentFailClosedBehavior',
  'finalizedChainAbsenceProcedure', 'auditedQuarantineProcedure',
  'selectedProcedure', 'senderUnblockAllowed', 'criterionSatisfied'
], 'expiredIntentRecoveryEvidence');
assert(recovery.requiredPolicy === 'finalized-chain-absence-or-explicit-audited-quarantine', 'expired-intent recovery policy drifted');
assert(recovery.currentFailClosedBehavior === 'block-sender-indefinitely', 'current expired-intent behavior drifted');
assert(recovery.finalizedChainAbsenceProcedure === 'missing', 'finalized-chain absence procedure must remain missing');
assert(recovery.auditedQuarantineProcedure === 'missing', 'audited quarantine procedure must remain missing');
assert(recovery.selectedProcedure === null, 'no unreviewed expired-intent procedure may be selected');
assert(recovery.senderUnblockAllowed === false, 'sender unblock must remain forbidden');
assert(recovery.criterionSatisfied === false, 'expired-intent recovery criterion must remain unsatisfied');

const bundle = manifest.releaseEvidenceBundle;
exactKeys(bundle, [
  'immutableBundleId', 'sha256', 'reviewers', 'reviewedAt',
  'allCriteriaSatisfied'
], 'releaseEvidenceBundle');
assert(bundle.immutableBundleId === null, 'immutable evidence bundle ID must remain absent');
assert(bundle.sha256 === null, 'immutable evidence bundle digest must remain absent');
exactArray(bundle.reviewers, [], 'release evidence reviewers');
assert(bundle.reviewedAt === null, 'release evidence review date must remain absent');
assert(bundle.allCriteriaSatisfied === false, 'release evidence bundle must remain incomplete');

exactKeys(manifest.blocker, ['code', 'reason'], 'blocker');
assert(manifest.blocker.code === 'ton-live-release-evidence-missing', 'blocker code drifted');
assert(
  manifest.blocker.reason === 'Independent Wallet V4R2 fee-parity or reviewed replacement evidence, exact endpoint credential provisioning attestations, a funded mainnet transfer evidence bundle, and a reviewed finalized-absence or audited-quarantine recovery procedure are not recorded.',
  'blocker reason drifted'
);
exactArray(manifest.exitCriteria, [
  'record-independent-exact-tonapi-wallet-v4r2-unsigned-signed-fee-parity-or-publish-a-reviewed-attested-local-replacement',
  'attest-the-exact-binary-owned-origin-release-credential-provisioning-and-registry-provenance',
  'record-an-immutable-funded-mainnet-wallet-v4r2-emulation-broadcast-reconciliation-fee-and-recipient-credit-evidence-bundle',
  'approve-a-finalized-chain-absence-procedure-or-an-explicit-audited-quarantine-and-recovery-procedure-for-expired-bearer-records',
  'review-the-complete-immutable-evidence-bundle-before-changing-the-production-runtime-policy'
], 'exit criteria');
NODE

node - "$SEND_CONTAINER" "$CHAIN_REGISTRY" "$TON_BUILDER" "$TON_SERVICE" <<'NODE'
const fs = require('node:fs');

function fail(message) {
  console.error(`[ton-send-readiness][ios][error] ${message}`);
  process.exit(1);
}

const stringMarkerPrefix = '__TON_SWIFT_STRING_LITERAL_';

function masked(value) {
  return value.replace(/[^\r\n]/g, ' ');
}

// This is deliberately a small, fail-closed Swift lexer rather than a regex-only
// comment stripper. Required release markers must not be sourced from comments,
// multiline strings, raw strings, or string interpolation text.
function lexSwift(source, label) {
  if (source.includes(stringMarkerPrefix)) {
    fail(`${label} contains the reserved lexer marker prefix`);
  }

  let output = '';
  const strings = [];
  let index = 0;

  while (index < source.length) {
    if (source.startsWith('//', index)) {
      const end = source.indexOf('\n', index + 2);
      const limit = end === -1 ? source.length : end;
      output += masked(source.slice(index, limit));
      index = limit;
      continue;
    }

    if (source.startsWith('/*', index)) {
      const start = index;
      let depth = 1;
      index += 2;
      while (index < source.length && depth > 0) {
        if (source.startsWith('/*', index)) {
          depth += 1;
          index += 2;
        } else if (source.startsWith('*/', index)) {
          depth -= 1;
          index += 2;
        } else {
          index += 1;
        }
      }
      if (depth !== 0) fail(`${label} contains an unterminated nested block comment`);
      output += masked(source.slice(start, index));
      continue;
    }

    let hashCount = 0;
    while (source[index + hashCount] === '#') hashCount += 1;
    const quoteIndex = index + hashCount;
    if (source[quoteIndex] === '"') {
      const multiline = source.startsWith('"""', quoteIndex);
      const quoteCount = multiline ? 3 : 1;
      const contentStart = quoteIndex + quoteCount;
      const closingDelimiter = '"'.repeat(quoteCount) + '#'.repeat(hashCount);
      let cursor = contentStart;
      let closingIndex = -1;

      while (cursor < source.length) {
        if (source.startsWith(closingDelimiter, cursor)) {
          closingIndex = cursor;
          break;
        }
        // In non-raw strings, an escape consumes the next source character. This
        // also prevents an escaped quote from becoming a false closing delimiter.
        if (hashCount === 0 && source[cursor] === '\\') {
          cursor = Math.min(cursor + 2, source.length);
        } else {
          cursor += 1;
        }
      }

      if (closingIndex === -1) fail(`${label} contains an unterminated Swift string literal`);
      const end = closingIndex + closingDelimiter.length;
      const value = source.slice(contentStart, closingIndex);
      const literalIndex = strings.length;
      strings.push({ value, hashCount, multiline });
      output += `${stringMarkerPrefix}${literalIndex}__`;
      output += source.slice(index, end).replace(/[^\r\n]/g, '');
      index = end;
      continue;
    }

    output += source[index];
    index += 1;
  }

  return { code: output, strings };
}

function stripBalancedOuterParentheses(expression) {
  let value = expression.trim();
  while (value.startsWith('(') && value.endsWith(')')) {
    let depth = 0;
    let enclosesWholeExpression = true;
    for (let index = 0; index < value.length; index += 1) {
      if (value[index] === '(') depth += 1;
      if (value[index] === ')') depth -= 1;
      if (depth === 0 && index < value.length - 1) {
        enclosesWholeExpression = false;
        break;
      }
      if (depth < 0) return value;
    }
    if (!enclosesWholeExpression || depth !== 0) break;
    value = value.slice(1, -1).trim();
  }
  return value;
}

function splitConditional(expression, operator) {
  const pieces = [];
  let depth = 0;
  let start = 0;
  for (let index = 0; index < expression.length; index += 1) {
    if (expression[index] === '(') depth += 1;
    if (expression[index] === ')') depth -= 1;
    if (depth === 0 && expression.startsWith(operator, index)) {
      pieces.push(expression.slice(start, index));
      start = index + operator.length;
      index += operator.length - 1;
    }
  }
  if (pieces.length === 0) return null;
  pieces.push(expression.slice(start));
  return pieces;
}

function evaluateConditional(expression, definitions) {
  const value = stripBalancedOuterParentheses(expression);
  const disjunction = splitConditional(value, '||');
  if (disjunction) {
    const results = disjunction.map((part) => evaluateConditional(part, definitions));
    if (results.includes(true)) return true;
    if (results.every((result) => result === false)) return false;
    return null;
  }
  const conjunction = splitConditional(value, '&&');
  if (conjunction) {
    const results = conjunction.map((part) => evaluateConditional(part, definitions));
    if (results.includes(false)) return false;
    if (results.every((result) => result === true)) return true;
    return null;
  }
  if (value.startsWith('!')) {
    const result = evaluateConditional(value.slice(1), definitions);
    return result === null ? null : !result;
  }
  if (value === 'true') return true;
  if (value === 'false') return false;
  if (definitions.has(value)) return definitions.get(value);
  return null;
}

// Unknown platform/compiler predicates are not treated as release-active. That
// conservative choice prevents an unproven branch from supplying a safety marker.
function activeConditionalCode(code, definitions, label) {
  const lines = code.match(/[^\n]*(?:\n|$)/g).filter((line) => line.length > 0);
  const stack = [];
  let active = true;
  let output = '';

  for (const line of lines) {
    const directive = line.trim();
    let match = directive.match(/^#if\s+(.+)$/);
    if (match) {
      const result = evaluateConditional(match[1], definitions);
      const frame = {
        parentActive: active,
        branchTaken: result === true,
        uncertain: result === null,
        currentActive: active && result === true
      };
      stack.push(frame);
      active = frame.currentActive;
      output += masked(line);
      continue;
    }

    match = directive.match(/^#elseif\s+(.+)$/);
    if (match) {
      const frame = stack.at(-1);
      if (!frame) fail(`${label} contains #elseif without #if`);
      const result = evaluateConditional(match[1], definitions);
      if (!frame.parentActive || frame.branchTaken || frame.uncertain) {
        frame.currentActive = false;
      } else if (result === true) {
        frame.currentActive = true;
        frame.branchTaken = true;
      } else {
        frame.currentActive = false;
        if (result === null) frame.uncertain = true;
      }
      active = frame.currentActive;
      output += masked(line);
      continue;
    }

    if (/^#else\b/.test(directive)) {
      const frame = stack.at(-1);
      if (!frame) fail(`${label} contains #else without #if`);
      frame.currentActive = frame.parentActive && !frame.branchTaken && !frame.uncertain;
      frame.branchTaken ||= frame.currentActive;
      active = frame.currentActive;
      output += masked(line);
      continue;
    }

    if (/^#endif\b/.test(directive)) {
      const frame = stack.pop();
      if (!frame) fail(`${label} contains #endif without #if`);
      active = frame.parentActive;
      output += masked(line);
      continue;
    }

    output += active ? line : masked(line);
  }

  if (stack.length !== 0) fail(`${label} contains an unterminated conditional-compilation block`);
  return output;
}

function count(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

const sendLexed = lexSwift(fs.readFileSync(process.argv[2], 'utf8'), 'send dependency container');
const registryLexed = lexSwift(fs.readFileSync(process.argv[3], 'utf8'), 'chain registry');
const builderLexed = lexSwift(fs.readFileSync(process.argv[4], 'utf8'), 'TON transaction builder');
const serviceLexed = lexSwift(fs.readFileSync(process.argv[5], 'utf8'), 'TON send service');
const send = sendLexed.code;
const registry = registryLexed.code;
const builder = builderLexed.code;
const service = serviceLexed.code;
const releaseDefinitions = new Map([['DEBUG', false]]);
const debugDefinitions = new Map([['DEBUG', true]]);
const releaseSend = activeConditionalCode(send, releaseDefinitions, 'send dependency container');
const debugSend = activeConditionalCode(send, debugDefinitions, 'send dependency container');
const releaseRegistry = activeConditionalCode(registry, releaseDefinitions, 'chain registry');

if (count(releaseSend, /static\s+let\s+production\s*=\s*TonProductionSendReleasePolicy\s*\(\s*isEnabled:\s*false\s*\)/g) !== 1) {
  fail('TON production policy must have exactly one active false initializer');
}
if (/static\s+let\s+production\s*=\s*TonProductionSendReleasePolicy\s*\(\s*isEnabled:\s*true\s*\)/.test(send)) {
  fail('TON production policy must never be enabled');
}
if (count(releaseSend, /private\s+init\s*\(\s*isEnabled:\s*Bool\s*\)/g) !== 1) {
  fail('TON release-policy initializer must remain private');
}
if (count(send, /enabledForTests\s*=\s*TonProductionSendReleasePolicy\s*\(\s*isEnabled:\s*true\s*\)/g) !== 1) {
  fail('TON DEBUG-only test policy must exist exactly once');
}
if (count(debugSend, /enabledForTests\s*=\s*TonProductionSendReleasePolicy\s*\(\s*isEnabled:\s*true\s*\)/g) !== 1 ||
    count(releaseSend, /enabledForTests\s*=/g) !== 0) {
  fail('TON enabledForTests policy escaped the DEBUG block');
}
if (count(releaseSend, /releasePolicy:\s*\.production/g) < 1) {
  fail('production send container must bind the default release policy');
}
if (count(releaseSend, /tonProductionSendDisabled/g) < 3) {
  fail('production TON routing fail-closed guards drifted');
}

const canonicalOriginMatches = [...releaseRegistry.matchAll(
  /canonicalAuthenticatedOrigin\s*=\s*URL\s*\(\s*string:\s*__TON_SWIFT_STRING_LITERAL_(\d+)__\s*\)!/g
)];
if (canonicalOriginMatches.length !== 1 ||
    registryLexed.strings[Number(canonicalOriginMatches[0][1])]?.value !== 'https://tonapi.io') {
  fail('canonical authenticated TonAPI origin drifted');
}
if (count(releaseRegistry, /reviewedProductionSendOrigins\s*=\s*\[\s*canonicalAuthenticatedOrigin\s*\]/g) !== 1) {
  fail('reviewed TonAPI send-origin allowlist drifted');
}
if (!/!bytes\.isEmpty\s*&&\s*bytes\.count\s*<=\s*4096\s*&&\s*bytes\.allSatisfy/.test(releaseRegistry) ||
    !/\(0x21\s*\.\.\.\s*0x7E\)\.contains\(byte\)/.test(releaseRegistry)) {
  fail('TonAPI release credential validation contract drifted');
}
if (!/var\s+hasReviewedProductionSendCredential:\s*Bool\s*\{[\s\S]{0,180}usesAuthorization\s*&&\s*Self\.isReviewedProductionSendServerURL\(tonAPIURL\)[\s\S]{0,80}\}/.test(releaseRegistry)) {
  fail('TonAPI signed-operation credential/origin binding drifted');
}

if (count(builder, /static\s+func\s+buildForFeeEstimation\s*\(/g) !== 1) {
  fail('Wallet V4R2 unsigned fee-estimation builder drifted');
}
if (!/func\s+emulateUnsigned\s*\([\s\S]{0,500}emulateMessageToTrace\s*\([\s\S]{0,240}ignore_signature_check:\s*true/.test(service)) {
  fail('TonAPI unsigned signature-bypass emulation seam drifted');
}
if (!/func\s+emulateSigned\s*\([\s\S]{0,500}requireTrustedSignedOperationEndpoint\(\)[\s\S]{0,240}emulateMessageToWallet\s*\(/.test(service)) {
  fail('TonAPI signed Wallet V4R2 emulation seam drifted');
}
if (count(service, /emulation\.totalFeeNanotons\s*!=\s*feeQuote\.feeNanotons/g) !== 2 ||
    count(service, /throw\s+TonSendServiceError\.feeChangedAfterConfirmation\s*\(/g) !== 2) {
  fail('signed-emulation fee drift must fail closed at both initial and retry seams');
}
NODE

require_fixed "$DOC" 'Status: **BLOCKED / fail closed**.' "blocked TON readiness status"
require_fixed "$DOC" 'exact `totalFeeNanotons` parity between TonAPI unsigned emulation' "exact unsigned/signed fee parity requirement"
require_fixed "$DOC" 'reviewed and attested local-TVM or quote mechanism' "reviewed attested replacement requirement"
require_fixed "$DOC" 'the Release binary' "Release endpoint provisioning requirement"
require_fixed "$DOC" 'real funded mainnet Wallet V4R2 transfer' "funded mainnet requirement"
require_fixed "$DOC" 'finalized-chain absence' "finalized-chain absence requirement"
require_fixed "$DOC" 'explicit audited quarantine and recovery procedure' "audited quarantine requirement"
require_fixed "$DOC" 'block that sender indefinitely' "current fail-closed recovery behavior"

require_fixed "$RELEASE_CHECKLIST" \
  '`bash ./scripts/test-ton-production-send-readiness-audit.sh && bash ./scripts/audit-ton-production-send-readiness.sh`' \
  "release-checklist TON readiness command"
require_fixed "$RELEASE_CHECKLIST" \
  '`config/ton-production-send-readiness.json` remains `blocked`' \
  "release-checklist machine-readable blocked status"
require_fixed "$RELEASE_CHECKLIST" \
  'exact fee parity with the corresponding signed Wallet V4R2' \
  "release-checklist exact fee parity requirement"
require_fixed "$RELEASE_CHECKLIST" \
  'reviewed attested quote/local-TVM mechanism' \
  "release-checklist reviewed replacement requirement"
require_fixed "$RELEASE_CHECKLIST" \
  'exact binary-owned send origin, credentials, and registry provenance' \
  "release-checklist endpoint credential requirement"
require_fixed "$RELEASE_CHECKLIST" \
  'funded mainnet Wallet V4R2 transfer' \
  "release-checklist funded mainnet requirement"
require_fixed "$RELEASE_CHECKLIST" \
  'finalized-chain absence proof or explicit audited quarantine' \
  "release-checklist finalized-absence or quarantine requirement"

require_active_line "$RUN_PR" \
  'bash "$WORKSPACE_DIR/scripts/test-ton-production-send-readiness-audit.sh"' \
  "PR CI TON readiness adversarial self-test"
require_active_line "$RUN_PR" \
  'bash "$WORKSPACE_DIR/scripts/audit-ton-production-send-readiness.sh"' \
  "PR CI TON readiness audit"
require_active_line "$WORKFLOW" \
  'bash ./scripts/test-ton-production-send-readiness-audit.sh' \
  "GitHub CI TON readiness adversarial self-test"
require_active_line "$WORKFLOW" \
  'bash ./scripts/audit-ton-production-send-readiness.sh' \
  "GitHub CI TON readiness audit"

echo "[ton-send-readiness][ios] blocked contract passed ($actual_manifest_sha256)"
