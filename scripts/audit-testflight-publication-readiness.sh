#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${TESTFLIGHT_PUBLICATION_AUDIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="$ROOT_DIR/config/testflight-publication-readiness.json"
DOC="$ROOT_DIR/docs/testflight-publication-readiness.md"
RELEASE_CHECKLIST="$ROOT_DIR/docs/release-checklist.md"
RUN_PR="$ROOT_DIR/scripts/ci/run-pr.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/codecov.yml"
AUDIT_CONTRACT="$ROOT_DIR/scripts/audit-testflight-publication-readiness.sh"
SELF_TEST="$ROOT_DIR/scripts/test-testflight-publication-readiness-audit.sh"
EXPECTED_MANIFEST_SHA256="${TESTFLIGHT_PUBLICATION_AUDIT_EXPECTED_MANIFEST_SHA256:-d66634ec2fce2305e2cc64e18e55c273dcc802bc82e074f658bef72ad8d53b26}"

fail() {
  echo "[testflight-publication][ios][error] $*" >&2
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

command -v node >/dev/null 2>&1 || fail "node is required for canonical JSON validation"

for path in \
  "$MANIFEST" "$DOC" "$RELEASE_CHECKLIST" "$RUN_PR" "$WORKFLOW" \
  "$AUDIT_CONTRACT" "$SELF_TEST"; do
  require_regular_file "$path"
done

require_executable_file "$AUDIT_CONTRACT"
require_executable_file "$SELF_TEST"
require_bounded_file "$MANIFEST" 32768 "TestFlight publication manifest"
require_bounded_file "$DOC" 65536 "TestFlight publication document"
require_bounded_file "$RELEASE_CHECKLIST" 262144 "release checklist"
require_bounded_file "$RUN_PR" 131072 "PR runner"
require_bounded_file "$WORKFLOW" 262144 "GitHub workflow"
require_bounded_file "$AUDIT_CONTRACT" 131072 "TestFlight publication audit"
require_bounded_file "$SELF_TEST" 262144 "TestFlight publication adversarial self-test"

[[ "$EXPECTED_MANIFEST_SHA256" =~ ^[0-9a-f]{64}$ ]] ||
  fail "expected manifest digest must be exactly 64 lowercase hexadecimal characters"
actual_manifest_sha256="$(sha256_file "$MANIFEST")"
[[ "$actual_manifest_sha256" == "$EXPECTED_MANIFEST_SHA256" ]] ||
  fail "publication manifest digest mismatch: expected $EXPECTED_MANIFEST_SHA256, got $actual_manifest_sha256"

node - "$MANIFEST" <<'NODE'
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = process.argv[2];
const raw = fs.readFileSync(path, 'utf8');
let manifest;

function fail(message) {
  console.error(`[testflight-publication][ios][error] ${message}`);
  process.exit(1);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

try {
  manifest = JSON.parse(raw);
} catch (error) {
  fail(`invalid publication JSON: ${error.message}`);
}

assert(
  raw === `${JSON.stringify(manifest, null, 2)}\n`,
  'publication manifest must use canonical two-space JSON without duplicate keys or trailing data'
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

function exactDigest(value, expected, label) {
  assert(typeof value === 'string' && /^[0-9a-f]{64}$/.test(value), `${label} must be a lowercase SHA-256`);
  assert(value === expected, `${label} drifted`);
}

exactKeys(manifest, [
  'schemaVersion', 'platform', 'distributionChannel', 'assessedAtUTC',
  'evidenceBoundary', 'artifact', 'upload', 'testFlight', 'symbolication',
  'readiness'
], 'top-level manifest');
assert(manifest.schemaVersion === 1, 'schemaVersion must be 1');
assert(manifest.platform === 'ios', 'platform must be ios');
assert(
  manifest.distributionChannel === 'testflight-external-public-link',
  'distribution channel drifted'
);
assert(manifest.assessedAtUTC === '2026-07-26T13:26:11Z', 'assessment timestamp drifted');

const boundary = manifest.evidenceBoundary;
exactKeys(boundary, [
  'contract', 'observationMethod', 'rawAttestationsTracked',
  'rawAttestationsLocation', 'currentStateRevalidationRequired'
], 'evidenceBoundary');
assert(
  boundary.contract === 'tracked-sanitized-publication-snapshot',
  'evidence boundary contract drifted'
);
assert(
  boundary.observationMethod ===
    'authenticated-app-store-connect-and-unauthenticated-public-link-in-safari',
  'observation method drifted'
);
assert(boundary.rawAttestationsTracked === false, 'ignored raw attestations must not be claimed as tracked');
assert(
  boundary.rawAttestationsLocation === 'ignored-build-output',
  'raw attestation location drifted'
);
assert(
  boundary.currentStateRevalidationRequired === true,
  'mutable App Store Connect state must require revalidation'
);

const artifact = manifest.artifact;
exactKeys(artifact, [
  'sourceCommit', 'bundleIdentifier', 'marketingVersion', 'buildNumber',
  'preUploadArchiveTreeSHA256', 'executableSHA256',
  'signedArchiveAuditReceiptSHA256',
  'preservedDataArchiveRehearsalResultSHA256'
], 'artifact');
assert(
  artifact.sourceCommit === 'f56b7b896344cfded39456217097747ef9efeacf',
  'artifact source commit drifted'
);
assert(
  artifact.bundleIdentifier === 'jp.co.soramitsu.fearlesswallet',
  'artifact bundle identifier drifted'
);
assert(artifact.marketingVersion === '4.2.0', 'artifact marketing version drifted');
assert(artifact.buildNumber === '2026.7.26', 'artifact build number drifted');
exactDigest(
  artifact.preUploadArchiveTreeSHA256,
  '301f19a4f1232fb05719d85b825ac081196fa5fb6988b58011b7569a4bd9e6fa',
  'pre-upload archive tree SHA-256'
);
exactDigest(
  artifact.executableSHA256,
  'cf0318792fc361bbd8704b21b6e1a08c4d81897f23492e4a807eab7f22403568',
  'executable SHA-256'
);
exactDigest(
  artifact.signedArchiveAuditReceiptSHA256,
  '1dbf38740b38403dde9cc7d4b1710cd28fdd5dc6f6f25990a7102020f11d1abc',
  'signed archive audit receipt SHA-256'
);
exactDigest(
  artifact.preservedDataArchiveRehearsalResultSHA256,
  '418d22cdd9e673ddfa1f47a49c666df11a740aac6737f6ef2b0328fa1b6a8641',
  'preserved-data archive rehearsal result SHA-256'
);

const upload = manifest.upload;
exactKeys(upload, [
  'status', 'uploadedAtUTC', 'postUploadArchiveTreeSHA256',
  'postUploadArchiveInfoPlistSHA256', 'postUploadAttestationSHA256',
  'xcodeMutation', 'reconstructedPreUploadArchiveTreeMatched',
  'embeddedAppSignatureVerified'
], 'upload');
assert(upload.status === 'success', 'upload status must remain success');
assert(upload.uploadedAtUTC === '2026-07-26T13:16:00Z', 'upload timestamp drifted');
exactDigest(
  upload.postUploadArchiveTreeSHA256,
  'a483a372fe8fd19761d3b0324427c4cf55a4553b4ed7433b34b78517f292cea7',
  'post-upload archive tree SHA-256'
);
exactDigest(
  upload.postUploadArchiveInfoPlistSHA256,
  'e82ff42b4b47713d1094c420dd7d1abfbfdfe7e7b80c972909936ad64e1e4756',
  'post-upload archive Info.plist SHA-256'
);
exactDigest(
  upload.postUploadAttestationSHA256,
  '6ede1d8fb981be149a82d69313be0ebc1838291e27d0ecf1c1576c95350b1af9',
  'post-upload attestation SHA-256'
);
assert(upload.xcodeMutation === 'Distributions-only', 'Xcode post-upload mutation scope drifted');
assert(
  upload.reconstructedPreUploadArchiveTreeMatched === true,
  'reconstructed pre-upload archive tree match must remain true'
);
assert(
  upload.embeddedAppSignatureVerified === true,
  'embedded app signature verification must remain true'
);

const testFlight = manifest.testFlight;
exactKeys(testFlight, [
  'processingStatus', 'externalTestingActive', 'externalGroup', 'publicLink',
  'whatToTestSHA256', 'automaticTesterNotification',
  'publicationAttestationSHA256'
], 'testFlight');
assert(testFlight.processingStatus === 'testing', 'TestFlight processing status must remain testing');
assert(testFlight.externalTestingActive === true, 'external TestFlight testing must remain active');

const group = testFlight.externalGroup;
exactKeys(group, [
  'name', 'id', 'testerCount', 'buildCount', 'containsBuild',
  'publicLinkTesterCount', 'publicLinkTesterLimit'
], 'externalGroup');
assert(group.name === 'Public Beta Test', 'external group name drifted');
assert(
  group.id === '9410949d-b468-40e5-b2f4-24055e65d270',
  'external group identifier drifted'
);
exactInteger(group.testerCount, 122, 'external group tester count snapshot');
exactInteger(group.buildCount, 2, 'external group build count snapshot');
assert(group.containsBuild === true, 'external group must contain build 2026.7.26');
exactInteger(group.publicLinkTesterCount, 120, 'public-link tester count snapshot');
exactInteger(group.publicLinkTesterLimit, 500, 'public-link tester limit');
assert(
  group.publicLinkTesterCount <= group.testerCount,
  'public-link tester count cannot exceed the external group tester count'
);
assert(
  group.publicLinkTesterCount <= group.publicLinkTesterLimit,
  'public-link tester count cannot exceed its limit'
);

const publicLink = testFlight.publicLink;
exactKeys(publicLink, [
  'enabled', 'shareableToAnyoneWithLink', 'url', 'urlSHA256',
  'landingPageResolved', 'landingPageApplicationName',
  'testFlightDeepLinkPresent'
], 'publicLink');
assert(publicLink.enabled === true, 'public TestFlight link must remain enabled');
assert(
  publicLink.shareableToAnyoneWithLink === true,
  'public TestFlight link must remain shareable to anyone with the link'
);
assert(
  publicLink.url === 'https://testflight.apple.com/join/012KzFyD',
  'public TestFlight URL drifted'
);
exactDigest(
  publicLink.urlSHA256,
  'd6599b1b9c0f7e77d9dd80d9185da67c1d864be5df9a7bbf360f245b099a000c',
  'public TestFlight URL SHA-256'
);
assert(
  crypto.createHash('sha256').update(publicLink.url, 'utf8').digest('hex') ===
    publicLink.urlSHA256,
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
assert(
  parsedPublicLink.username === '' && parsedPublicLink.password === '',
  'public TestFlight URL must not contain userinfo'
);
assert(
  parsedPublicLink.search === '' && parsedPublicLink.hash === '',
  'public TestFlight URL must not contain a query or fragment'
);
assert(parsedPublicLink.pathname === '/join/012KzFyD', 'public TestFlight URL path drifted');
assert(publicLink.landingPageResolved === true, 'public landing page resolution must remain true');
assert(
  publicLink.landingPageApplicationName === 'Fearless Wallet: DeFi Wallet',
  'public landing-page application identity drifted'
);
assert(
  publicLink.testFlightDeepLinkPresent === true,
  'public landing page must retain the TestFlight deep link'
);
exactDigest(
  testFlight.whatToTestSHA256,
  'd5d0c2063934c4ca7dd8bb82af038d79909738c93cf96c11ab63bca8c0b7f272',
  'What to Test text SHA-256'
);
assert(
  testFlight.automaticTesterNotification === true,
  'automatic tester notification must remain recorded as enabled'
);
exactDigest(
  testFlight.publicationAttestationSHA256,
  '84e53d78316cf46cc1956d04e86782241d6e575da90fef109acaaf44cb368d4c',
  'publication attestation SHA-256'
);

const symbolication = manifest.symbolication;
exactKeys(symbolication, [
  'status', 'runtimeInstallLaunchOrMigrationImpact', 'mainApplicationDSYMPresent',
  'runtimeFrameworkMissingVendorDSYM', 'staticStubFrameworkWarnings',
  'productionFollowUpRequired'
], 'symbolication');
assert(
  symbolication.status === 'degraded-third-party-symbolication',
  'symbolication status drifted'
);
assert(
  symbolication.runtimeInstallLaunchOrMigrationImpact === false,
  'dSYM warnings must not be classified as an install, launch, or migration runtime failure'
);
assert(
  symbolication.mainApplicationDSYMPresent === true,
  'main application dSYM presence must remain recorded'
);
assert(
  symbolication.runtimeFrameworkMissingVendorDSYM === 'MPQRCoreSDK.framework',
  'runtime framework vendor-dSYM gap drifted'
);
exactArray(symbolication.staticStubFrameworkWarnings, [
  'blake2lib.framework',
  'libed25519.framework',
  'sr25519lib.framework'
], 'static stub framework warning inventory');
assert(
  symbolication.productionFollowUpRequired === true,
  'third-party production symbolication follow-up must remain required'
);

const readiness = manifest.readiness;
exactKeys(readiness, [
  'status', 'publicationVerified', 'externalTestingActive',
  'exactAppleDeliveredInstallVerified',
  'preservedDataPostInstallRehearsalVerified', 'releaseEnabled',
  'blockerCode', 'requiredAction'
], 'readiness');
assert(readiness.status === 'blocked', 'TestFlight readiness must remain blocked');
assert(readiness.publicationVerified === true, 'publicationVerified must remain true');
assert(readiness.externalTestingActive === true, 'readiness externalTestingActive must remain true');
assert(
  readiness.exactAppleDeliveredInstallVerified === false,
  'exact Apple-delivered TestFlight installation must not be claimed'
);
assert(
  readiness.preservedDataPostInstallRehearsalVerified === false,
  'post-install preserved-data rehearsal must not be claimed'
);
assert(readiness.releaseEnabled === false, 'releaseEnabled must remain false');
assert(
  readiness.blockerCode === 'testflight-exact-build-preserved-data-install-pending',
  'TestFlight blocker code drifted'
);
assert(
  readiness.requiredAction ===
    'Update in place through TestFlight without deleting or clearing app data, then repeat the five-cold-launch and store-integrity rehearsal.',
  'TestFlight required action drifted'
);
assert(
  readiness.publicationVerified ===
    (
      upload.status === 'success' &&
      testFlight.processingStatus === 'testing' &&
      testFlight.externalTestingActive === true &&
      group.containsBuild === true &&
      publicLink.enabled === true &&
      publicLink.shareableToAnyoneWithLink === true &&
      publicLink.landingPageResolved === true &&
      publicLink.testFlightDeepLinkPresent === true
    ),
  'publicationVerified disagrees with upload, group, or public-link evidence'
);
assert(
  readiness.externalTestingActive === testFlight.externalTestingActive,
  'readiness externalTestingActive disagrees with TestFlight state'
);
assert(
  readiness.releaseEnabled === false ||
    (
      readiness.publicationVerified === true &&
      readiness.exactAppleDeliveredInstallVerified === true &&
      readiness.preservedDataPostInstallRehearsalVerified === true &&
      symbolication.productionFollowUpRequired === false
    ),
  'releaseEnabled requires publication, exact Apple-delivered install, preserved-data rehearsal, and symbolication closure'
);
NODE

require_fixed "$DOC" 'Status: **BLOCKED only on exact Apple-delivered install/rehearsal and symbolication follow-up**' \
  "documented current TestFlight readiness status"
require_fixed "$DOC" '`4.2.0 (2026.7.26)` is `Testing`' \
  "documented current TestFlight build status"
require_fixed "$DOC" '`9410949d-b468-40e5-b2f4-24055e65d270`' \
  "documented external group identifier"
require_fixed "$DOC" '`122` testers, `2` builds' \
  "documented external group snapshot"
require_fixed "$DOC" '`120/500` public-link places used' \
  "documented public-link occupancy snapshot"
require_fixed "$DOC" 'https://testflight.apple.com/join/012KzFyD' \
  "documented public TestFlight link"
require_fixed "$DOC" 'must not be treated as canonical release source' \
  "documented ignored raw-attestation boundary"
require_fixed "$DOC" 'MPQRCoreSDK.framework' \
  "documented runtime framework symbolication gap"
require_fixed "$DOC" 'Do not uninstall the app or clear its container.' \
  "documented preserved-data install constraint"
require_fixed "$RELEASE_CHECKLIST" \
  'bash ./scripts/test-testflight-publication-readiness-audit.sh && bash ./scripts/audit-testflight-publication-readiness.sh' \
  "release-checklist TestFlight publication gate"
require_fixed "$RELEASE_CHECKLIST" \
  'build release-enabled until an in-place TestFlight update preserves the' \
  "release-checklist exact Apple-delivered install gate"
require_active_line "$RUN_PR" \
  'bash "$WORKSPACE_DIR/scripts/test-testflight-publication-readiness-audit.sh"' \
  "PR TestFlight publication adversarial self-test"
require_active_line "$RUN_PR" \
  'bash "$WORKSPACE_DIR/scripts/audit-testflight-publication-readiness.sh"' \
  "PR TestFlight publication audit"
require_active_line "$WORKFLOW" \
  'bash ./scripts/test-testflight-publication-readiness-audit.sh' \
  "CI TestFlight publication adversarial self-test"
require_active_line "$WORKFLOW" \
  'bash ./scripts/audit-testflight-publication-readiness.sh' \
  "CI TestFlight publication audit"

echo "[testflight-publication][ios] tracked publication evidence is valid; exact Apple-delivered install remains blocked"
