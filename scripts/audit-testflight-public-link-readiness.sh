#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${TESTFLIGHT_PUBLIC_LINK_AUDIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="$ROOT_DIR/config/testflight-public-link-readiness.json"
DOC="$ROOT_DIR/docs/testflight-public-link-readiness.md"
RELEASE_CHECKLIST="$ROOT_DIR/docs/release-checklist.md"
RUN_PR="$ROOT_DIR/scripts/ci/run-pr.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/codecov.yml"
AUDIT_CONTRACT="$ROOT_DIR/scripts/audit-testflight-public-link-readiness.sh"
SELF_TEST="$ROOT_DIR/scripts/test-testflight-public-link-readiness-audit.sh"
EXPECTED_MANIFEST_SHA256="${TESTFLIGHT_PUBLIC_LINK_AUDIT_EXPECTED_MANIFEST_SHA256:-9ecaa3bc18594c5086e10e6b25f1a64075c010f5a6d962731799a8d2c9075855}"

fail() {
  echo "[testflight-public-link][ios][error] $*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

require_regular_file() {
  local path="$1"
  [[ -f "$path" && ! -L "$path" ]] ||
    fail "required regular file is missing or is a symlink: ${path#"$ROOT_DIR/"}"
}

require_executable_file() {
  local path="$1"
  [[ -x "$path" ]] || fail "required script is not executable: ${path#"$ROOT_DIR/"}"
}

require_bounded_file() {
  local path="$1"
  local maximum="$2"
  local label="$3"
  local bytes
  bytes="$(wc -c < "$path" | tr -d '[:space:]')"
  [[ "$bytes" =~ ^[0-9]+$ && "$bytes" -gt 0 && "$bytes" -le "$maximum" ]] ||
    fail "$label must be nonempty and no larger than $maximum bytes"
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
  "$MANIFEST" "$DOC" "$RELEASE_CHECKLIST" "$RUN_PR" "$WORKFLOW" \
  "$AUDIT_CONTRACT" "$SELF_TEST"; do
  require_regular_file "$path"
done

require_executable_file "$AUDIT_CONTRACT"
require_executable_file "$SELF_TEST"
require_bounded_file "$MANIFEST" 32768 "TestFlight evidence manifest"
require_bounded_file "$DOC" 65536 "TestFlight evidence document"
require_bounded_file "$RELEASE_CHECKLIST" 262144 "release checklist"
require_bounded_file "$RUN_PR" 131072 "PR runner"
require_bounded_file "$WORKFLOW" 262144 "GitHub workflow"
require_bounded_file "$AUDIT_CONTRACT" 131072 "TestFlight evidence audit"
require_bounded_file "$SELF_TEST" 262144 "TestFlight adversarial self-test"

[[ "$EXPECTED_MANIFEST_SHA256" =~ ^[0-9a-f]{64}$ ]] ||
  fail "expected manifest digest must be exactly 64 lowercase hexadecimal characters"
actual_manifest_sha256="$(sha256_file "$MANIFEST")"
[[ "$actual_manifest_sha256" == "$EXPECTED_MANIFEST_SHA256" ]] ||
  fail "evidence manifest digest mismatch: expected $EXPECTED_MANIFEST_SHA256, got $actual_manifest_sha256"

node - "$MANIFEST" <<'NODE'
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = process.argv[2];
const raw = fs.readFileSync(path, 'utf8');
let manifest;

function fail(message) {
  console.error(`[testflight-public-link][ios][error] ${message}`);
  process.exit(1);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

try {
  manifest = JSON.parse(raw);
} catch (error) {
  fail(`invalid evidence JSON: ${error.message}`);
}

assert(
  raw === `${JSON.stringify(manifest, null, 2)}\n`,
  'evidence manifest must use canonical two-space JSON without duplicate keys or trailing data'
);

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

function exactInteger(value, expected, label) {
  assert(Number.isSafeInteger(value), `${label} must be a safe integer`);
  assert(value === expected, `${label} drifted`);
}

exactKeys(manifest, [
  'schemaVersion', 'platform', 'distributionChannel', 'assessedAt',
  'evidenceSource', 'account', 'app', 'externalGroup', 'build',
  'publicLink', 'landingPage', 'readiness', 'blocker', 'exitCriteria'
], 'top-level manifest');
assert(manifest.schemaVersion === 1, 'schemaVersion must be 1');
assert(manifest.platform === 'ios', 'platform must be ios');
assert(
  manifest.distributionChannel === 'testflight-external-public-link',
  'distribution channel drifted'
);
assert(manifest.assessedAt === '2026-07-16', 'assessment date drifted');

const source = manifest.evidenceSource;
exactKeys(source, [
  'method', 'observedAt', 'locale', 'screenshotArtifact',
  'appStoreConnectApiAttestation', 'currentStateRevalidationRequired'
], 'evidenceSource');
assert(source.method === 'interactive-safari-visual-inspection', 'evidence method drifted');
assert(source.observedAt === '2026-07-16', 'evidence observation date drifted');
assert(source.locale === 'ja', 'evidence locale drifted');
assert(source.screenshotArtifact === null, 'a screenshot artifact must not be claimed');
assert(source.appStoreConnectApiAttestation === null, 'an App Store Connect API attestation must not be claimed');
assert(source.currentStateRevalidationRequired === true, 'live TestFlight state must require revalidation');

exactKeys(manifest.account, ['provider', 'signedInObserved'], 'account');
assert(manifest.account.provider === 'Soramitsu Co., Ltd.', 'observed provider drifted');
assert(manifest.account.signedInObserved === true, 'signed-in observation drifted');

exactKeys(manifest.app, ['displayName', 'appStoreConnectRecordMatched'], 'app');
assert(manifest.app.displayName === 'Fearless Wallet: DeFi Wallet', 'app display name drifted');
assert(manifest.app.appStoreConnectRecordMatched === true, 'App Store Connect record match drifted');

const group = manifest.externalGroup;
exactKeys(group, [
  'name', 'headerTesterCount', 'headerBuildCount', 'publicLinkEnabled'
], 'externalGroup');
assert(group.name === 'Public Beta Test', 'external group name drifted');
exactInteger(group.headerTesterCount, 120, 'external group header tester count');
exactInteger(group.headerBuildCount, 1, 'external group header build count');
assert(group.publicLinkEnabled === true, 'external group public link must remain recorded as enabled');

const build = manifest.build;
exactKeys(build, [
  'marketingVersion', 'buildNumber', 'displayIdentifier', 'reviewStatus',
  'observedLocalizedStatus', 'submittedForReview', 'externalBetaApproved',
  'daysUntilExpiry', 'deviceInstallVerified'
], 'build');
assert(build.marketingVersion === '4.2.0', 'TestFlight marketing version drifted');
assert(build.buildNumber === '2026.7.15', 'TestFlight build number drifted');
assert(build.displayIdentifier === '4.2.0 (2026.7.15)', 'TestFlight display identifier drifted');
assert(build.reviewStatus === 'in-review', 'build review status must remain in-review');
assert(build.observedLocalizedStatus === '審査中', 'localized in-review status drifted');
assert(build.submittedForReview === true, 'build must remain recorded as submitted for review');
assert(build.externalBetaApproved === false, 'external beta approval must not be claimed');
exactInteger(build.daysUntilExpiry, 90, 'observed build expiry countdown');
assert(build.deviceInstallVerified === false, 'current-build device installation must not be claimed');

const publicLink = manifest.publicLink;
exactKeys(publicLink, [
  'enabled', 'url', 'urlSha256', 'host', 'path', 'testerLimit',
  'publicLinkTesterCount', 'remainingPublicLinkCapacity',
  'shareableToAnyoneWithLink'
], 'publicLink');
assert(publicLink.enabled === true, 'public link must remain recorded as enabled');
assert(publicLink.url === 'https://testflight.apple.com/join/012KzFyD', 'public TestFlight URL drifted');
assert(
  publicLink.urlSha256 === 'd6599b1b9c0f7e77d9dd80d9185da67c1d864be5df9a7bbf360f245b099a000c',
  'public TestFlight URL digest drifted'
);
assert(
  crypto.createHash('sha256').update(publicLink.url, 'utf8').digest('hex') === publicLink.urlSha256,
  'public TestFlight URL does not match its SHA-256'
);
let parsedPublicLink;
try {
  parsedPublicLink = new URL(publicLink.url);
} catch (error) {
  fail(`public TestFlight URL is invalid: ${error.message}`);
}
assert(parsedPublicLink.protocol === 'https:', 'public TestFlight URL must use HTTPS');
assert(parsedPublicLink.hostname === 'testflight.apple.com', 'public TestFlight URL host drifted');
assert(parsedPublicLink.port === '', 'public TestFlight URL must not specify a port');
assert(parsedPublicLink.username === '' && parsedPublicLink.password === '', 'public TestFlight URL must not contain userinfo');
assert(parsedPublicLink.search === '' && parsedPublicLink.hash === '', 'public TestFlight URL must not contain a query or fragment');
assert(parsedPublicLink.pathname === '/join/012KzFyD', 'public TestFlight URL path drifted');
assert(publicLink.host === parsedPublicLink.hostname, 'recorded public-link host does not match the URL');
assert(publicLink.path === parsedPublicLink.pathname, 'recorded public-link path does not match the URL');
exactInteger(publicLink.testerLimit, 500, 'public-link tester limit');
exactInteger(publicLink.publicLinkTesterCount, 118, 'public-link tester count');
exactInteger(publicLink.remainingPublicLinkCapacity, 382, 'public-link remaining capacity');
assert(
  publicLink.testerLimit - publicLink.publicLinkTesterCount === publicLink.remainingPublicLinkCapacity,
  'public-link capacity arithmetic drifted'
);
assert(publicLink.shareableToAnyoneWithLink === true, 'anyone-with-link sharing must remain recorded as enabled');

const landing = manifest.landingPage;
exactKeys(landing, [
  'resolvedInSafari', 'url', 'title', 'appDescriptionPresent', 'callToAction',
  'appleOwnedPage', 'currentBuildIdentityVisible',
  'currentBuildInstallabilityProven'
], 'landingPage');
assert(landing.resolvedInSafari === true, 'Safari landing-page resolution drifted');
assert(landing.url === publicLink.url, 'landing-page URL must equal the public TestFlight URL');
assert(
  landing.title === 'Join the beta for Fearless Wallet: DeFi Wallet - TestFlight - Apple',
  'TestFlight landing-page title drifted'
);
assert(landing.appDescriptionPresent === true, 'Fearless Wallet landing-page description observation drifted');
assert(landing.callToAction === 'View in TestFlight', 'TestFlight landing-page call to action drifted');
assert(landing.appleOwnedPage === true, 'Apple-owned landing-page observation drifted');
assert(landing.currentBuildIdentityVisible === false, 'the public landing page must not be claimed to identify the current build');
assert(landing.currentBuildInstallabilityProven === false, 'landing-page resolution must not be treated as installability proof');

const readiness = manifest.readiness;
exactKeys(readiness, [
  'status', 'linkEnabled', 'linkResolves', 'submittedForReview',
  'externalBetaApproved', 'deviceInstallVerified', 'releaseEnabled'
], 'readiness');
assert(readiness.status === 'blocked', 'TestFlight readiness status must remain blocked');
assert(readiness.linkEnabled === true, 'linkEnabled must remain true');
assert(readiness.linkResolves === true, 'linkResolves must remain true');
assert(readiness.submittedForReview === true, 'submittedForReview must remain true');
assert(readiness.externalBetaApproved === false, 'externalBetaApproved must remain false');
assert(readiness.deviceInstallVerified === false, 'deviceInstallVerified must remain false');
assert(readiness.releaseEnabled === false, 'releaseEnabled must remain false');
assert(readiness.linkEnabled === publicLink.enabled, 'readiness linkEnabled disagrees with publicLink.enabled');
assert(readiness.linkEnabled === group.publicLinkEnabled, 'readiness linkEnabled disagrees with the external group');
assert(readiness.linkResolves === landing.resolvedInSafari, 'readiness linkResolves disagrees with the landing-page observation');
assert(readiness.submittedForReview === build.submittedForReview, 'readiness submittedForReview disagrees with the build');
assert(readiness.externalBetaApproved === build.externalBetaApproved, 'readiness externalBetaApproved disagrees with the build');
assert(readiness.deviceInstallVerified === build.deviceInstallVerified, 'readiness deviceInstallVerified disagrees with the build');
assert(
  readiness.releaseEnabled === false ||
    (readiness.externalBetaApproved === true && readiness.deviceInstallVerified === true),
  'releaseEnabled requires both external beta approval and exact-build device installation evidence'
);

exactKeys(manifest.blocker, ['code', 'reason'], 'blocker');
assert(
  manifest.blocker.code === 'testflight-external-beta-review-pending',
  'TestFlight blocker code drifted'
);
assert(
  manifest.blocker.reason === 'The exact external build is still in TestFlight review, and no clean-device installation of that build through the public link has been verified.',
  'TestFlight blocker reason drifted'
);
exactArray(manifest.exitCriteria, [
  'observe-external-beta-approval-for-exact-build-4.2.0-2026.7.15',
  'install-from-the-public-link-on-a-clean-eligible-device-and-confirm-the-exact-version-and-build',
  'record-reviewed-install-evidence-without-credentials-or-device-identifiers',
  'revalidate-live-app-store-connect-and-public-landing-page-state-before-changing-release-enabled'
], 'exit criteria');
NODE

require_fixed "$AUDIT_CONTRACT" \
  'TESTFLIGHT_PUBLIC_LINK_AUDIT_EXPECTED_MANIFEST_SHA256:-9ecaa3bc18594c5086e10e6b25f1a64075c010f5a6d962731799a8d2c9075855' \
  "audit-pinned TestFlight evidence digest"
require_active_line "$SELF_TEST" 'EXPECTED_CASES=80' \
  "TestFlight self-test exact case sentinel"
require_fixed "$SELF_TEST" 'executed $CASES cases; expected exactly $EXPECTED_CASES' \
  "TestFlight self-test runtime count enforcement"
require_fixed "$SELF_TEST" 'passed $CASES cases (1 valid + 79 negative/adversarial)' \
  "TestFlight self-test completion inventory"

require_fixed "$DOC" 'Status: **BLOCKED / fail closed**.' \
  "blocked TestFlight readiness status"
require_fixed "$DOC" 'https://testflight.apple.com/join/012KzFyD' \
  "documented exact public TestFlight link"
require_fixed "$DOC" '`linkEnabled=true` and `submittedForReview=true`' \
  "documented positive TestFlight observations"
require_fixed "$DOC" '`externalBetaApproved=false`, `deviceInstallVerified=false`, and `releaseEnabled=false`' \
  "documented fail-closed TestFlight claims"
require_fixed "$DOC" '118 of the 500 public-link places' \
  "documented public-link capacity observation"
require_fixed "$DOC" 'does not prove that build `4.2.0 (2026.7.15)` can currently be installed' \
  "documented landing-page evidence limitation"
require_fixed "$DOC" 'offline and never contacts Apple' \
  "documented offline audit boundary"

require_fixed "$RELEASE_CHECKLIST" \
  '`bash ./scripts/test-testflight-public-link-readiness-audit.sh && bash ./scripts/audit-testflight-public-link-readiness.sh`' \
  "release-checklist TestFlight evidence command"
require_fixed "$RELEASE_CHECKLIST" \
  '`externalBetaApproved=false`, `deviceInstallVerified=false`, and `releaseEnabled=false`' \
  "release-checklist fail-closed TestFlight state"
require_fixed "$RELEASE_CHECKLIST" \
  'Landing-page resolution alone is not install evidence for the current build.' \
  "release-checklist TestFlight evidence limitation"

require_active_line "$RUN_PR" \
  'bash "$WORKSPACE_DIR/scripts/test-testflight-public-link-readiness-audit.sh"' \
  "PR CI TestFlight adversarial self-test"
require_active_line "$RUN_PR" \
  'bash "$WORKSPACE_DIR/scripts/audit-testflight-public-link-readiness.sh"' \
  "PR CI TestFlight evidence audit"
require_active_line "$WORKFLOW" \
  'bash ./scripts/test-testflight-public-link-readiness-audit.sh' \
  "GitHub CI TestFlight adversarial self-test"
require_active_line "$WORKFLOW" \
  'bash ./scripts/audit-testflight-public-link-readiness.sh' \
  "GitHub CI TestFlight evidence audit"

echo "[testflight-public-link][ios] blocked evidence contract passed ($actual_manifest_sha256)"
