#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT_DIR/scripts/audit-testflight-public-link-readiness.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/testflight-public-link-test.XXXXXX")"
CASES=0
EXPECTED_CASES=80

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

fail() {
  echo "[testflight-public-link-test][error] $*" >&2
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
    "$fixture/scripts/ci" \
    "$fixture/.github/workflows"
  cp "$ROOT_DIR/config/testflight-public-link-readiness.json" "$fixture/config/"
  cp "$ROOT_DIR/docs/testflight-public-link-readiness.md" "$fixture/docs/"
  cp "$ROOT_DIR/docs/release-checklist.md" "$fixture/docs/"
  cp "$ROOT_DIR/scripts/ci/run-pr.sh" "$fixture/scripts/ci/"
  cp "$ROOT_DIR/.github/workflows/codecov.yml" "$fixture/.github/workflows/"
  cp "$ROOT_DIR/scripts/audit-testflight-public-link-readiness.sh" "$fixture/scripts/"
  cp "$ROOT_DIR/scripts/test-testflight-public-link-readiness-audit.sh" "$fixture/scripts/"
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
const document = JSON.parse(fs.readFileSync(path, 'utf8'));
const segments = fieldPath.split('.');
let cursor = document;
for (const segment of segments.slice(0, -1)) cursor = cursor[segment];
cursor[segments.at(-1)] = JSON.parse(encoded);
fs.writeFileSync(path, `${JSON.stringify(document, null, 2)}\n`);
NODE
}

delete_json() {
  local manifest="$1"
  local field_path="$2"
  node - "$manifest" "$field_path" <<'NODE'
const fs = require('node:fs');
const [path, fieldPath] = process.argv.slice(2);
const document = JSON.parse(fs.readFileSync(path, 'utf8'));
const segments = fieldPath.split('.');
let cursor = document;
for (const segment of segments.slice(0, -1)) cursor = cursor[segment];
if (!Object.prototype.hasOwnProperty.call(cursor, segments.at(-1))) {
  throw new Error(`missing JSON field for deletion: ${fieldPath}`);
}
delete cursor[segments.at(-1)];
fs.writeFileSync(path, `${JSON.stringify(document, null, 2)}\n`);
NODE
}

replace_once() {
  local path="$1"
  local needle="$2"
  local replacement="$3"
  node - "$path" "$needle" "$replacement" <<'NODE'
const fs = require('node:fs');
const [path, needle, replacement] = process.argv.slice(2);
const source = fs.readFileSync(path, 'utf8');
const first = source.indexOf(needle);
if (first === -1) throw new Error(`mutation marker is missing in ${path}: ${needle}`);
if (source.indexOf(needle, first + needle.length) !== -1) {
  throw new Error(`mutation marker is ambiguous in ${path}: ${needle}`);
}
fs.writeFileSync(path, source.slice(0, first) + replacement + source.slice(first + needle.length));
NODE
}

replace_first() {
  local path="$1"
  local needle="$2"
  local replacement="$3"
  node - "$path" "$needle" "$replacement" <<'NODE'
const fs = require('node:fs');
const [path, needle, replacement] = process.argv.slice(2);
const source = fs.readFileSync(path, 'utf8');
const first = source.indexOf(needle);
if (first === -1) throw new Error(`mutation marker is missing in ${path}: ${needle}`);
fs.writeFileSync(path, source.slice(0, first) + replacement + source.slice(first + needle.length));
NODE
}

expect_failure_with_digest() {
  local label="$1"
  local fixture="$2"
  local digest="$3"
  local expected="$4"
  local output status=0
  output="$(
    TESTFLIGHT_PUBLIC_LINK_AUDIT_ROOT="$fixture" \
    TESTFLIGHT_PUBLIC_LINK_AUDIT_EXPECTED_MANIFEST_SHA256="$digest" \
      bash "$AUDIT" 2>&1
  )" || status=$?
  [[ "$status" -ne 0 ]] || fail "$label unexpectedly passed"
  grep -Fq -- "$expected" <<<"$output" ||
    fail "$label failed for the wrong reason; expected '$expected', got: $output"
  CASES=$((CASES + 1))
  echo "[testflight-public-link-test] rejected $label"
}

expect_failure() {
  local label="$1"
  local fixture="$2"
  local expected="$3"
  local digest
  digest="$(sha256_file "$fixture/config/testflight-public-link-readiness.json")"
  expect_failure_with_digest "$label" "$fixture" "$digest" "$expected"
}

baseline="$(new_fixture baseline)"
TESTFLIGHT_PUBLIC_LINK_AUDIT_ROOT="$baseline" bash "$AUDIT" >/dev/null ||
  fail "valid blocked TestFlight baseline was rejected"
CASES=$((CASES + 1))
echo "[testflight-public-link-test] accepted valid blocked baseline"

fixture="$(new_fixture schema-version)"
set_json "$fixture/config/testflight-public-link-readiness.json" schemaVersion 2
expect_failure "schema version drift" "$fixture" "schemaVersion must be 1"

fixture="$(new_fixture platform)"
set_json "$fixture/config/testflight-public-link-readiness.json" platform '"android"'
expect_failure "platform drift" "$fixture" "platform must be ios"

fixture="$(new_fixture distribution-channel)"
set_json "$fixture/config/testflight-public-link-readiness.json" distributionChannel '"app-store-production"'
expect_failure "distribution channel drift" "$fixture" "distribution channel drifted"

fixture="$(new_fixture assessment-date)"
set_json "$fixture/config/testflight-public-link-readiness.json" assessedAt '"2026-07-17"'
expect_failure "assessment date drift" "$fixture" "assessment date drifted"

fixture="$(new_fixture evidence-method)"
set_json "$fixture/config/testflight-public-link-readiness.json" evidenceSource.method '"api"'
expect_failure "fabricated API evidence method" "$fixture" "evidence method drifted"

fixture="$(new_fixture observation-date)"
set_json "$fixture/config/testflight-public-link-readiness.json" evidenceSource.observedAt '"2026-07-17"'
expect_failure "observation date drift" "$fixture" "evidence observation date drifted"

fixture="$(new_fixture evidence-locale)"
set_json "$fixture/config/testflight-public-link-readiness.json" evidenceSource.locale '"en"'
expect_failure "observation locale drift" "$fixture" "evidence locale drifted"

fixture="$(new_fixture screenshot-claim)"
set_json "$fixture/config/testflight-public-link-readiness.json" evidenceSource.screenshotArtifact '"proof.png"'
expect_failure "unrecorded screenshot claim" "$fixture" "a screenshot artifact must not be claimed"

fixture="$(new_fixture api-attestation-claim)"
set_json "$fixture/config/testflight-public-link-readiness.json" evidenceSource.appStoreConnectApiAttestation '"verified"'
expect_failure "unrecorded API attestation claim" "$fixture" "an App Store Connect API attestation must not be claimed"

fixture="$(new_fixture no-revalidation)"
set_json "$fixture/config/testflight-public-link-readiness.json" evidenceSource.currentStateRevalidationRequired false
expect_failure "disabled live-state revalidation" "$fixture" "live TestFlight state must require revalidation"

fixture="$(new_fixture provider)"
set_json "$fixture/config/testflight-public-link-readiness.json" account.provider '"Unknown"'
expect_failure "provider drift" "$fixture" "observed provider drifted"

fixture="$(new_fixture signed-in-observation)"
set_json "$fixture/config/testflight-public-link-readiness.json" account.signedInObserved false
expect_failure "removed signed-in observation" "$fixture" "signed-in observation drifted"

fixture="$(new_fixture app-name)"
set_json "$fixture/config/testflight-public-link-readiness.json" app.displayName '"Fearless"'
expect_failure "app identity drift" "$fixture" "app display name drifted"

fixture="$(new_fixture app-record-match)"
set_json "$fixture/config/testflight-public-link-readiness.json" app.appStoreConnectRecordMatched false
expect_failure "removed App Store Connect record match" "$fixture" "App Store Connect record match drifted"

fixture="$(new_fixture group-name)"
set_json "$fixture/config/testflight-public-link-readiness.json" externalGroup.name '"Internal Testers"'
expect_failure "external group drift" "$fixture" "external group name drifted"

fixture="$(new_fixture group-testers)"
set_json "$fixture/config/testflight-public-link-readiness.json" externalGroup.headerTesterCount 119
expect_failure "group tester-count drift" "$fixture" "external group header tester count drifted"

fixture="$(new_fixture group-builds)"
set_json "$fixture/config/testflight-public-link-readiness.json" externalGroup.headerBuildCount 2
expect_failure "group build-count drift" "$fixture" "external group header build count drifted"

fixture="$(new_fixture group-link-disabled)"
set_json "$fixture/config/testflight-public-link-readiness.json" externalGroup.publicLinkEnabled false
expect_failure "group public-link state drift" "$fixture" "external group public link must remain recorded as enabled"

fixture="$(new_fixture build-version)"
set_json "$fixture/config/testflight-public-link-readiness.json" build.marketingVersion '"4.2.1"'
expect_failure "marketing version drift" "$fixture" "TestFlight marketing version drifted"

fixture="$(new_fixture build-number)"
set_json "$fixture/config/testflight-public-link-readiness.json" build.buildNumber '"2026.7.16"'
expect_failure "build number drift" "$fixture" "TestFlight build number drifted"

fixture="$(new_fixture build-display)"
set_json "$fixture/config/testflight-public-link-readiness.json" build.displayIdentifier '"4.2.0 (2026.7.16)"'
expect_failure "build display drift" "$fixture" "TestFlight display identifier drifted"

fixture="$(new_fixture premature-review-approval)"
set_json "$fixture/config/testflight-public-link-readiness.json" build.reviewStatus '"approved"'
expect_failure "premature review-status approval" "$fixture" "build review status must remain in-review"

fixture="$(new_fixture localized-status)"
set_json "$fixture/config/testflight-public-link-readiness.json" build.observedLocalizedStatus '"承認済み"'
expect_failure "localized review-status drift" "$fixture" "localized in-review status drifted"

fixture="$(new_fixture submission-removed)"
set_json "$fixture/config/testflight-public-link-readiness.json" build.submittedForReview false
expect_failure "removed review submission" "$fixture" "build must remain recorded as submitted for review"

fixture="$(new_fixture premature-build-approval)"
set_json "$fixture/config/testflight-public-link-readiness.json" build.externalBetaApproved true
expect_failure "premature external beta approval" "$fixture" "external beta approval must not be claimed"

fixture="$(new_fixture expiry-countdown)"
set_json "$fixture/config/testflight-public-link-readiness.json" build.daysUntilExpiry 89
expect_failure "expiry-countdown drift" "$fixture" "observed build expiry countdown drifted"

fixture="$(new_fixture premature-build-install)"
set_json "$fixture/config/testflight-public-link-readiness.json" build.deviceInstallVerified true
expect_failure "premature current-build install claim" "$fixture" "current-build device installation must not be claimed"

fixture="$(new_fixture public-link-disabled)"
set_json "$fixture/config/testflight-public-link-readiness.json" publicLink.enabled false
expect_failure "public-link enabled-state drift" "$fixture" "public link must remain recorded as enabled"

fixture="$(new_fixture public-link-token)"
set_json "$fixture/config/testflight-public-link-readiness.json" publicLink.url '"https://testflight.apple.com/join/00000000"'
expect_failure "public-link token drift" "$fixture" "public TestFlight URL drifted"

fixture="$(new_fixture public-link-digest)"
set_json "$fixture/config/testflight-public-link-readiness.json" publicLink.urlSha256 '"0000000000000000000000000000000000000000000000000000000000000000"'
expect_failure "public-link digest drift" "$fixture" "public TestFlight URL digest drifted"

fixture="$(new_fixture public-link-host)"
set_json "$fixture/config/testflight-public-link-readiness.json" publicLink.host '"evil.example"'
expect_failure "recorded public-link host drift" "$fixture" "recorded public-link host does not match the URL"

fixture="$(new_fixture public-link-path)"
set_json "$fixture/config/testflight-public-link-readiness.json" publicLink.path '"/join/00000000"'
expect_failure "recorded public-link path drift" "$fixture" "recorded public-link path does not match the URL"

fixture="$(new_fixture tester-limit)"
set_json "$fixture/config/testflight-public-link-readiness.json" publicLink.testerLimit 501
expect_failure "public-link tester-limit drift" "$fixture" "public-link tester limit drifted"

fixture="$(new_fixture public-link-testers)"
set_json "$fixture/config/testflight-public-link-readiness.json" publicLink.publicLinkTesterCount 119
expect_failure "public-link tester-count drift" "$fixture" "public-link tester count drifted"

fixture="$(new_fixture remaining-capacity)"
set_json "$fixture/config/testflight-public-link-readiness.json" publicLink.remainingPublicLinkCapacity 381
expect_failure "public-link remaining-capacity drift" "$fixture" "public-link remaining capacity drifted"

fixture="$(new_fixture anyone-with-link)"
set_json "$fixture/config/testflight-public-link-readiness.json" publicLink.shareableToAnyoneWithLink false
expect_failure "anyone-with-link state drift" "$fixture" "anyone-with-link sharing must remain recorded as enabled"

fixture="$(new_fixture landing-unresolved)"
set_json "$fixture/config/testflight-public-link-readiness.json" landingPage.resolvedInSafari false
expect_failure "removed landing-page resolution" "$fixture" "Safari landing-page resolution drifted"

fixture="$(new_fixture landing-url)"
set_json "$fixture/config/testflight-public-link-readiness.json" landingPage.url '"https://example.com/"'
expect_failure "landing-page URL drift" "$fixture" "landing-page URL must equal the public TestFlight URL"

fixture="$(new_fixture landing-title)"
set_json "$fixture/config/testflight-public-link-readiness.json" landingPage.title '"TestFlight"'
expect_failure "landing-page title drift" "$fixture" "TestFlight landing-page title drifted"

fixture="$(new_fixture landing-description)"
set_json "$fixture/config/testflight-public-link-readiness.json" landingPage.appDescriptionPresent false
expect_failure "removed app-description observation" "$fixture" "Fearless Wallet landing-page description observation drifted"

fixture="$(new_fixture landing-cta)"
set_json "$fixture/config/testflight-public-link-readiness.json" landingPage.callToAction '"Install"'
expect_failure "landing-page CTA drift" "$fixture" "TestFlight landing-page call to action drifted"

fixture="$(new_fixture landing-owner)"
set_json "$fixture/config/testflight-public-link-readiness.json" landingPage.appleOwnedPage false
expect_failure "removed Apple-page observation" "$fixture" "Apple-owned landing-page observation drifted"

fixture="$(new_fixture fabricated-build-identity)"
set_json "$fixture/config/testflight-public-link-readiness.json" landingPage.currentBuildIdentityVisible true
expect_failure "fabricated landing-page build identity" "$fixture" "the public landing page must not be claimed to identify the current build"

fixture="$(new_fixture fabricated-installability)"
set_json "$fixture/config/testflight-public-link-readiness.json" landingPage.currentBuildInstallabilityProven true
expect_failure "fabricated landing-page installability" "$fixture" "landing-page resolution must not be treated as installability proof"

fixture="$(new_fixture ready-status)"
set_json "$fixture/config/testflight-public-link-readiness.json" readiness.status '"ready"'
expect_failure "premature readiness status" "$fixture" "TestFlight readiness status must remain blocked"

fixture="$(new_fixture readiness-link-disabled)"
set_json "$fixture/config/testflight-public-link-readiness.json" readiness.linkEnabled false
expect_failure "readiness link-enabled drift" "$fixture" "linkEnabled must remain true"

fixture="$(new_fixture readiness-link-unresolved)"
set_json "$fixture/config/testflight-public-link-readiness.json" readiness.linkResolves false
expect_failure "readiness link-resolution drift" "$fixture" "linkResolves must remain true"

fixture="$(new_fixture readiness-not-submitted)"
set_json "$fixture/config/testflight-public-link-readiness.json" readiness.submittedForReview false
expect_failure "readiness submission drift" "$fixture" "submittedForReview must remain true"

fixture="$(new_fixture readiness-approved)"
set_json "$fixture/config/testflight-public-link-readiness.json" readiness.externalBetaApproved true
expect_failure "readiness external-approval fabrication" "$fixture" "externalBetaApproved must remain false"

fixture="$(new_fixture readiness-installed)"
set_json "$fixture/config/testflight-public-link-readiness.json" readiness.deviceInstallVerified true
expect_failure "readiness install fabrication" "$fixture" "deviceInstallVerified must remain false"

fixture="$(new_fixture release-enabled)"
set_json "$fixture/config/testflight-public-link-readiness.json" readiness.releaseEnabled true
expect_failure "premature release enablement" "$fixture" "releaseEnabled must remain false"

fixture="$(new_fixture blocker-code)"
set_json "$fixture/config/testflight-public-link-readiness.json" blocker.code '"ready"'
expect_failure "blocker-code removal" "$fixture" "TestFlight blocker code drifted"

fixture="$(new_fixture blocker-reason)"
set_json "$fixture/config/testflight-public-link-readiness.json" blocker.reason '"Approved"'
expect_failure "blocker-reason removal" "$fixture" "TestFlight blocker reason drifted"

fixture="$(new_fixture exit-criteria)"
set_json "$fixture/config/testflight-public-link-readiness.json" exitCriteria '[]'
expect_failure "removed exit criteria" "$fixture" "exit criteria drifted"

fixture="$(new_fixture unknown-top-level-key)"
set_json "$fixture/config/testflight-public-link-readiness.json" unexpected '"decoy"'
expect_failure "unknown top-level manifest key" "$fixture" "top-level manifest keys drifted"

fixture="$(new_fixture missing-readiness)"
delete_json "$fixture/config/testflight-public-link-readiness.json" readiness
expect_failure "missing readiness object" "$fixture" "top-level manifest keys drifted"

fixture="$(new_fixture unknown-nested-key)"
set_json "$fixture/config/testflight-public-link-readiness.json" evidenceSource.unexpected true
expect_failure "unknown nested manifest key" "$fixture" "evidenceSource keys drifted"

fixture="$(new_fixture wrong-object-type)"
set_json "$fixture/config/testflight-public-link-readiness.json" evidenceSource '[]'
expect_failure "wrong nested object type" "$fixture" "evidenceSource must be an object"

fixture="$(new_fixture duplicate-json-key)"
replace_once "$fixture/config/testflight-public-link-readiness.json" \
  '  "schemaVersion": 1,' \
  $'  "schemaVersion": 1,\n  "schemaVersion": 1,'
expect_failure "duplicate JSON key" "$fixture" "evidence manifest must use canonical two-space JSON without duplicate keys or trailing data"

fixture="$(new_fixture invalid-json)"
replace_once "$fixture/config/testflight-public-link-readiness.json" \
  '  "schemaVersion": 1,' \
  '  "schemaVersion": invalid,'
expect_failure "invalid evidence JSON" "$fixture" "invalid evidence JSON"

fixture="$(new_fixture oversized-json)"
dd if=/dev/zero bs=33000 count=1 2>/dev/null | tr '\0' ' ' >> "$fixture/config/testflight-public-link-readiness.json"
expect_failure "oversized evidence manifest" "$fixture" "TestFlight evidence manifest must be nonempty and no larger than 32768 bytes"

fixture="$(new_fixture digest-mismatch)"
set_json "$fixture/config/testflight-public-link-readiness.json" assessedAt '"2026-07-17"'
expect_failure_with_digest "unpinned manifest mutation" "$fixture" \
  "$(sha256_file "$ROOT_DIR/config/testflight-public-link-readiness.json")" \
  "evidence manifest digest mismatch"

fixture="$(new_fixture invalid-expected-digest)"
expect_failure_with_digest "invalid expected manifest digest" "$fixture" \
  "NOT-A-DIGEST" \
  "expected manifest digest must be exactly 64 lowercase hexadecimal characters"

fixture="$(new_fixture manifest-symlink)"
rm "$fixture/config/testflight-public-link-readiness.json"
ln -s ../docs/testflight-public-link-readiness.md "$fixture/config/testflight-public-link-readiness.json"
expect_failure_with_digest "symlinked evidence manifest" "$fixture" \
  "$(printf '0%.0s' {1..64})" \
  "required regular file is missing or is a symlink"

fixture="$(new_fixture document-symlink)"
rm "$fixture/docs/testflight-public-link-readiness.md"
ln -s release-checklist.md "$fixture/docs/testflight-public-link-readiness.md"
expect_failure "symlinked evidence document" "$fixture" "required regular file is missing or is a symlink"

fixture="$(new_fixture checklist-symlink)"
rm "$fixture/docs/release-checklist.md"
ln -s testflight-public-link-readiness.md "$fixture/docs/release-checklist.md"
expect_failure "symlinked release checklist" "$fixture" "required regular file is missing or is a symlink"

fixture="$(new_fixture run-pr-symlink)"
rm "$fixture/scripts/ci/run-pr.sh"
ln -s ../audit-testflight-public-link-readiness.sh "$fixture/scripts/ci/run-pr.sh"
expect_failure "symlinked PR runner" "$fixture" "required regular file is missing or is a symlink"

fixture="$(new_fixture workflow-symlink)"
rm "$fixture/.github/workflows/codecov.yml"
ln -s ../../docs/release-checklist.md "$fixture/.github/workflows/codecov.yml"
expect_failure "symlinked GitHub workflow" "$fixture" "required regular file is missing or is a symlink"

fixture="$(new_fixture audit-symlink)"
rm "$fixture/scripts/audit-testflight-public-link-readiness.sh"
ln -s test-testflight-public-link-readiness-audit.sh "$fixture/scripts/audit-testflight-public-link-readiness.sh"
expect_failure "symlinked TestFlight audit" "$fixture" "required regular file is missing or is a symlink"

fixture="$(new_fixture self-test-symlink)"
rm "$fixture/scripts/test-testflight-public-link-readiness-audit.sh"
ln -s audit-testflight-public-link-readiness.sh "$fixture/scripts/test-testflight-public-link-readiness-audit.sh"
expect_failure "symlinked TestFlight self-test" "$fixture" "required regular file is missing or is a symlink"

fixture="$(new_fixture audit-not-executable)"
chmod 0644 "$fixture/scripts/audit-testflight-public-link-readiness.sh"
expect_failure "non-executable TestFlight audit" "$fixture" "required script is not executable: scripts/audit-testflight-public-link-readiness.sh"

fixture="$(new_fixture self-test-not-executable)"
chmod 0644 "$fixture/scripts/test-testflight-public-link-readiness-audit.sh"
expect_failure "non-executable TestFlight self-test" "$fixture" "required script is not executable: scripts/test-testflight-public-link-readiness-audit.sh"

fixture="$(new_fixture document-approval-claim)"
replace_once "$fixture/docs/testflight-public-link-readiness.md" \
  '`externalBetaApproved=false`, `deviceInstallVerified=false`, and `releaseEnabled=false`' \
  '`externalBetaApproved=true`, `deviceInstallVerified=true`, and `releaseEnabled=true`'
expect_failure "fabricated approval in evidence document" "$fixture" "documented fail-closed TestFlight claims"

fixture="$(new_fixture checklist-command)"
replace_once "$fixture/docs/release-checklist.md" \
  '`bash ./scripts/test-testflight-public-link-readiness-audit.sh && bash ./scripts/audit-testflight-public-link-readiness.sh`' \
  '`echo skipped-testflight-evidence`'
expect_failure "removed release-checklist command" "$fixture" "release-checklist TestFlight evidence command"

fixture="$(new_fixture run-pr-self-test)"
replace_once "$fixture/scripts/ci/run-pr.sh" \
  'bash "$WORKSPACE_DIR/scripts/test-testflight-public-link-readiness-audit.sh"' \
  'echo removed-testflight-self-test'
expect_failure "removed PR CI TestFlight self-test" "$fixture" "PR CI TestFlight adversarial self-test"

fixture="$(new_fixture run-pr-audit)"
replace_once "$fixture/scripts/ci/run-pr.sh" \
  'bash "$WORKSPACE_DIR/scripts/audit-testflight-public-link-readiness.sh"' \
  'echo removed-testflight-audit'
expect_failure "removed PR CI TestFlight audit" "$fixture" "PR CI TestFlight evidence audit"

fixture="$(new_fixture workflow-self-test)"
replace_once "$fixture/.github/workflows/codecov.yml" \
  'bash ./scripts/test-testflight-public-link-readiness-audit.sh' \
  'echo removed-testflight-self-test'
expect_failure "removed GitHub CI TestFlight self-test" "$fixture" "GitHub CI TestFlight adversarial self-test"

fixture="$(new_fixture workflow-audit)"
replace_once "$fixture/.github/workflows/codecov.yml" \
  'bash ./scripts/audit-testflight-public-link-readiness.sh' \
  'echo removed-testflight-audit'
expect_failure "removed GitHub CI TestFlight audit" "$fixture" "GitHub CI TestFlight evidence audit"

fixture="$(new_fixture fixture-count-sentinel)"
replace_first "$fixture/scripts/test-testflight-public-link-readiness-audit.sh" \
  'EXPECTED_CASES=80' \
  'EXPECTED_CASES=81'
expect_failure "mutated TestFlight fixture-count sentinel" "$fixture" "TestFlight self-test exact case sentinel"

if ((CASES != EXPECTED_CASES)); then
  fail "executed $CASES cases; expected exactly $EXPECTED_CASES"
fi

echo "[testflight-public-link-test] passed $CASES cases (1 valid + 79 negative/adversarial)"
