#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT_DIR/scripts/audit-testflight-publication-readiness.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/testflight-publication-test.XXXXXX")"
CASES=0
EXPECTED_CASES=70

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

fail() {
  echo "[testflight-publication-test][error] $*" >&2
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
  cp "$ROOT_DIR/config/testflight-publication-readiness.json" "$fixture/config/"
  cp "$ROOT_DIR/docs/testflight-publication-readiness.md" "$fixture/docs/"
  cp "$ROOT_DIR/docs/release-checklist.md" "$fixture/docs/"
  cp "$ROOT_DIR/scripts/ci/run-pr.sh" "$fixture/scripts/ci/"
  cp "$ROOT_DIR/.github/workflows/codecov.yml" "$fixture/.github/workflows/"
  cp "$ROOT_DIR/scripts/audit-testflight-publication-readiness.sh" "$fixture/scripts/"
  cp "$ROOT_DIR/scripts/test-testflight-publication-readiness-audit.sh" "$fixture/scripts/"
  chmod +x \
    "$fixture/scripts/audit-testflight-publication-readiness.sh" \
    "$fixture/scripts/test-testflight-publication-readiness-audit.sh"
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

expect_failure_with_digest() {
  local label="$1"
  local fixture="$2"
  local digest="$3"
  local expected="$4"
  local output status=0
  output="$(
    TESTFLIGHT_PUBLICATION_AUDIT_ROOT="$fixture" \
    TESTFLIGHT_PUBLICATION_AUDIT_EXPECTED_MANIFEST_SHA256="$digest" \
      bash "$AUDIT" 2>&1
  )" || status=$?
  [[ "$status" -ne 0 ]] || fail "$label unexpectedly passed"
  grep -Fq -- "$expected" <<<"$output" ||
    fail "$label failed for the wrong reason; expected '$expected', got: $output"
  CASES=$((CASES + 1))
  echo "[testflight-publication-test] rejected $label"
}

expect_failure() {
  local label="$1"
  local fixture="$2"
  local expected="$3"
  local digest
  digest="$(sha256_file "$fixture/config/testflight-publication-readiness.json")"
  expect_failure_with_digest "$label" "$fixture" "$digest" "$expected"
}

baseline="$(new_fixture baseline)"
TESTFLIGHT_PUBLICATION_AUDIT_ROOT="$baseline" bash "$AUDIT" >/dev/null ||
  fail "valid blocked TestFlight publication baseline was rejected"
CASES=$((CASES + 1))
echo "[testflight-publication-test] accepted valid blocked baseline"

fixture="$(new_fixture schema-version)"
set_json "$fixture/config/testflight-publication-readiness.json" schemaVersion 2
expect_failure "schema version drift" "$fixture" "schemaVersion must be 1"

fixture="$(new_fixture platform)"
set_json "$fixture/config/testflight-publication-readiness.json" platform '"android"'
expect_failure "platform drift" "$fixture" "platform must be ios"

fixture="$(new_fixture distribution-channel)"
set_json "$fixture/config/testflight-publication-readiness.json" distributionChannel '"app-store-production"'
expect_failure "distribution channel drift" "$fixture" "distribution channel drifted"

fixture="$(new_fixture assessment-timestamp)"
set_json "$fixture/config/testflight-publication-readiness.json" assessedAtUTC '"2026-07-26T13:26:12Z"'
expect_failure "assessment timestamp drift" "$fixture" "assessment timestamp drifted"

fixture="$(new_fixture evidence-contract)"
set_json "$fixture/config/testflight-publication-readiness.json" evidenceBoundary.contract '"raw-build-output"'
expect_failure "evidence boundary drift" "$fixture" "evidence boundary contract drifted"

fixture="$(new_fixture evidence-method)"
set_json "$fixture/config/testflight-publication-readiness.json" evidenceBoundary.observationMethod '"api"'
expect_failure "fabricated observation method" "$fixture" "observation method drifted"

fixture="$(new_fixture raw-tracked)"
set_json "$fixture/config/testflight-publication-readiness.json" evidenceBoundary.rawAttestationsTracked true
expect_failure "ignored raw attestations claimed tracked" "$fixture" "ignored raw attestations must not be claimed as tracked"

fixture="$(new_fixture raw-location)"
set_json "$fixture/config/testflight-publication-readiness.json" evidenceBoundary.rawAttestationsLocation '"tracked-source"'
expect_failure "raw attestation location drift" "$fixture" "raw attestation location drifted"

fixture="$(new_fixture stale-state-accepted)"
set_json "$fixture/config/testflight-publication-readiness.json" evidenceBoundary.currentStateRevalidationRequired false
expect_failure "mutable state revalidation removed" "$fixture" "mutable App Store Connect state must require revalidation"

fixture="$(new_fixture source-commit)"
set_json "$fixture/config/testflight-publication-readiness.json" artifact.sourceCommit '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "artifact source commit drift" "$fixture" "artifact source commit drifted"

fixture="$(new_fixture bundle-id)"
set_json "$fixture/config/testflight-publication-readiness.json" artifact.bundleIdentifier '"jp.co.soramitsu.fearlesswallet.dev"'
expect_failure "artifact bundle drift" "$fixture" "artifact bundle identifier drifted"

fixture="$(new_fixture build-number)"
set_json "$fixture/config/testflight-publication-readiness.json" artifact.buildNumber '"2026.7.15"'
expect_failure "artifact build drift" "$fixture" "artifact build number drifted"

fixture="$(new_fixture archive-digest)"
set_json "$fixture/config/testflight-publication-readiness.json" artifact.preUploadArchiveTreeSHA256 '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "archive tree digest drift" "$fixture" "pre-upload archive tree SHA-256 drifted"

fixture="$(new_fixture executable-digest)"
set_json "$fixture/config/testflight-publication-readiness.json" artifact.executableSHA256 '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "executable digest drift" "$fixture" "executable SHA-256 drifted"

fixture="$(new_fixture receipt-digest)"
set_json "$fixture/config/testflight-publication-readiness.json" artifact.signedArchiveAuditReceiptSHA256 '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "signed audit receipt drift" "$fixture" "signed archive audit receipt SHA-256 drifted"

fixture="$(new_fixture rehearsal-digest)"
set_json "$fixture/config/testflight-publication-readiness.json" artifact.preservedDataArchiveRehearsalResultSHA256 '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "archive rehearsal result drift" "$fixture" "preserved-data archive rehearsal result SHA-256 drifted"

fixture="$(new_fixture upload-status)"
set_json "$fixture/config/testflight-publication-readiness.json" upload.status '"failed"'
expect_failure "upload success removed" "$fixture" "upload status must remain success"

fixture="$(new_fixture upload-time)"
set_json "$fixture/config/testflight-publication-readiness.json" upload.uploadedAtUTC '"2026-07-26T13:17:00Z"'
expect_failure "upload timestamp drift" "$fixture" "upload timestamp drifted"

fixture="$(new_fixture post-upload-tree)"
set_json "$fixture/config/testflight-publication-readiness.json" upload.postUploadArchiveTreeSHA256 '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "post-upload tree drift" "$fixture" "post-upload archive tree SHA-256 drifted"

fixture="$(new_fixture post-upload-attestation)"
set_json "$fixture/config/testflight-publication-readiness.json" upload.postUploadAttestationSHA256 '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "post-upload attestation drift" "$fixture" "post-upload attestation SHA-256 drifted"

fixture="$(new_fixture xcode-mutation)"
set_json "$fixture/config/testflight-publication-readiness.json" upload.xcodeMutation '"unbounded"'
expect_failure "Xcode mutation scope widened" "$fixture" "Xcode post-upload mutation scope drifted"

fixture="$(new_fixture reconstructed-tree)"
set_json "$fixture/config/testflight-publication-readiness.json" upload.reconstructedPreUploadArchiveTreeMatched false
expect_failure "reconstructed tree mismatch accepted" "$fixture" "reconstructed pre-upload archive tree match must remain true"

fixture="$(new_fixture signature)"
set_json "$fixture/config/testflight-publication-readiness.json" upload.embeddedAppSignatureVerified false
expect_failure "embedded signature failure accepted" "$fixture" "embedded app signature verification must remain true"

fixture="$(new_fixture processing-status)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.processingStatus '"ready-to-submit"'
expect_failure "TestFlight status regressed" "$fixture" "TestFlight processing status must remain testing"

fixture="$(new_fixture external-testing)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.externalTestingActive false
expect_failure "external testing disabled" "$fixture" "external TestFlight testing must remain active"

fixture="$(new_fixture group-name)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.externalGroup.name '"Internal Only"'
expect_failure "external group drift" "$fixture" "external group name drifted"

fixture="$(new_fixture group-id)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.externalGroup.id '"00000000-0000-0000-0000-000000000000"'
expect_failure "external group identifier drift" "$fixture" "external group identifier drifted"

fixture="$(new_fixture group-testers)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.externalGroup.testerCount 123
expect_failure "external group tester snapshot drift" "$fixture" "external group tester count snapshot drifted"

fixture="$(new_fixture group-builds)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.externalGroup.buildCount 1
expect_failure "external group build snapshot drift" "$fixture" "external group build count snapshot drifted"

fixture="$(new_fixture group-missing-build)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.externalGroup.containsBuild false
expect_failure "external group build assignment removed" "$fixture" "external group must contain build 2026.7.26"

fixture="$(new_fixture public-count)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.externalGroup.publicLinkTesterCount 121
expect_failure "public-link tester snapshot drift" "$fixture" "public-link tester count snapshot drifted"

fixture="$(new_fixture public-limit)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.externalGroup.publicLinkTesterLimit 501
expect_failure "public-link limit drift" "$fixture" "public-link tester limit drifted"

fixture="$(new_fixture link-disabled)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.publicLink.enabled false
expect_failure "public link disabled" "$fixture" "public TestFlight link must remain enabled"

fixture="$(new_fixture link-private)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.publicLink.shareableToAnyoneWithLink false
expect_failure "anyone-with-link access removed" "$fixture" "public TestFlight link must remain shareable to anyone with the link"

fixture="$(new_fixture link-origin)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.publicLink.url '"https://evil.example/join/012KzFyD"'
expect_failure "hostile public-link origin" "$fixture" "public TestFlight URL drifted"

fixture="$(new_fixture link-digest)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.publicLink.urlSHA256 '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "public-link digest drift" "$fixture" "public TestFlight URL SHA-256 drifted"

fixture="$(new_fixture landing-page)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.publicLink.landingPageResolved false
expect_failure "landing page resolution removed" "$fixture" "public landing page resolution must remain true"

fixture="$(new_fixture app-name)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.publicLink.landingPageApplicationName '"Lookalike Wallet"'
expect_failure "landing-page app identity drift" "$fixture" "public landing-page application identity drifted"

fixture="$(new_fixture deep-link)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.publicLink.testFlightDeepLinkPresent false
expect_failure "TestFlight deep link removed" "$fixture" "public landing page must retain the TestFlight deep link"

fixture="$(new_fixture what-to-test)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.whatToTestSHA256 '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "What to Test digest drift" "$fixture" "What to Test text SHA-256 drifted"

fixture="$(new_fixture notifications)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.automaticTesterNotification false
expect_failure "tester notification drift" "$fixture" "automatic tester notification must remain recorded as enabled"

fixture="$(new_fixture publication-attestation)"
set_json "$fixture/config/testflight-publication-readiness.json" testFlight.publicationAttestationSHA256 '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
expect_failure "publication attestation drift" "$fixture" "publication attestation SHA-256 drifted"

fixture="$(new_fixture symbolication-status)"
set_json "$fixture/config/testflight-publication-readiness.json" symbolication.status '"complete"'
expect_failure "symbolication falsely closed" "$fixture" "symbolication status drifted"

fixture="$(new_fixture dsym-runtime-impact)"
set_json "$fixture/config/testflight-publication-readiness.json" symbolication.runtimeInstallLaunchOrMigrationImpact true
expect_failure "dSYM warning misclassified as runtime failure" "$fixture" "dSYM warnings must not be classified as an install, launch, or migration runtime failure"

fixture="$(new_fixture app-dsym)"
set_json "$fixture/config/testflight-publication-readiness.json" symbolication.mainApplicationDSYMPresent false
expect_failure "main app dSYM removed" "$fixture" "main application dSYM presence must remain recorded"

fixture="$(new_fixture vendor-dsym)"
set_json "$fixture/config/testflight-publication-readiness.json" symbolication.runtimeFrameworkMissingVendorDSYM '"sr25519lib.framework"'
expect_failure "runtime vendor dSYM gap drift" "$fixture" "runtime framework vendor-dSYM gap drifted"

fixture="$(new_fixture static-stubs)"
set_json "$fixture/config/testflight-publication-readiness.json" symbolication.staticStubFrameworkWarnings '["libed25519.framework","blake2lib.framework","sr25519lib.framework"]'
expect_failure "static-stub warning order drift" "$fixture" "static stub framework warning inventory drifted"

fixture="$(new_fixture symbolication-followup)"
set_json "$fixture/config/testflight-publication-readiness.json" symbolication.productionFollowUpRequired false
expect_failure "symbolication follow-up prematurely closed" "$fixture" "third-party production symbolication follow-up must remain required"

fixture="$(new_fixture ready-status)"
set_json "$fixture/config/testflight-publication-readiness.json" readiness.status '"ready"'
expect_failure "premature readiness status" "$fixture" "TestFlight readiness must remain blocked"

fixture="$(new_fixture publication-unverified)"
set_json "$fixture/config/testflight-publication-readiness.json" readiness.publicationVerified false
expect_failure "publication verification removed" "$fixture" "publicationVerified must remain true"

fixture="$(new_fixture readiness-external)"
set_json "$fixture/config/testflight-publication-readiness.json" readiness.externalTestingActive false
expect_failure "readiness external testing drift" "$fixture" "readiness externalTestingActive must remain true"

fixture="$(new_fixture install-fabrication)"
set_json "$fixture/config/testflight-publication-readiness.json" readiness.exactAppleDeliveredInstallVerified true
expect_failure "exact Apple-delivered install fabricated" "$fixture" "exact Apple-delivered TestFlight installation must not be claimed"

fixture="$(new_fixture rehearsal-fabrication)"
set_json "$fixture/config/testflight-publication-readiness.json" readiness.preservedDataPostInstallRehearsalVerified true
expect_failure "post-install rehearsal fabricated" "$fixture" "post-install preserved-data rehearsal must not be claimed"

fixture="$(new_fixture release-enabled)"
set_json "$fixture/config/testflight-publication-readiness.json" readiness.releaseEnabled true
expect_failure "release prematurely enabled" "$fixture" "releaseEnabled must remain false"

fixture="$(new_fixture blocker-code)"
set_json "$fixture/config/testflight-publication-readiness.json" readiness.blockerCode '"ready"'
expect_failure "install blocker removed" "$fixture" "TestFlight blocker code drifted"

fixture="$(new_fixture required-action)"
set_json "$fixture/config/testflight-publication-readiness.json" readiness.requiredAction '"Delete and reinstall."'
expect_failure "destructive install action accepted" "$fixture" "TestFlight required action drifted"

fixture="$(new_fixture extra-key)"
set_json "$fixture/config/testflight-publication-readiness.json" unexpected true
expect_failure "unexpected manifest key" "$fixture" "top-level manifest keys drifted"

fixture="$(new_fixture duplicate-key)"
replace_once "$fixture/config/testflight-publication-readiness.json" \
  $'{\n  "schemaVersion": 1,' \
  $'{\n  "schemaVersion": 1,\n  "schemaVersion": 1,'
expect_failure "duplicate manifest key" "$fixture" "canonical two-space JSON without duplicate keys or trailing data"

fixture="$(new_fixture trailing-data)"
printf '%s\n' '{"unexpected":true}' >> "$fixture/config/testflight-publication-readiness.json"
expect_failure "trailing JSON data" "$fixture" "invalid publication JSON"

fixture="$(new_fixture digest-mismatch)"
set_json "$fixture/config/testflight-publication-readiness.json" schemaVersion 2
expect_failure_with_digest \
  "manifest digest mismatch" \
  "$fixture" \
  "d66634ec2fce2305e2cc64e18e55c273dcc802bc82e074f658bef72ad8d53b26" \
  "publication manifest digest mismatch"

fixture="$(new_fixture invalid-expected-digest)"
expect_failure_with_digest \
  "invalid expected digest" \
  "$fixture" \
  "not-a-digest" \
  "expected manifest digest must be exactly 64 lowercase hexadecimal characters"

fixture="$(new_fixture manifest-symlink)"
mv "$fixture/config/testflight-publication-readiness.json" "$fixture/config/manifest.real"
ln -s manifest.real "$fixture/config/testflight-publication-readiness.json"
expect_failure_with_digest \
  "manifest symlink substitution" \
  "$fixture" \
  "d66634ec2fce2305e2cc64e18e55c273dcc802bc82e074f658bef72ad8d53b26" \
  "required regular file is missing or is a symlink: config/testflight-publication-readiness.json"

fixture="$(new_fixture missing-manifest)"
rm "$fixture/config/testflight-publication-readiness.json"
expect_failure_with_digest \
  "missing manifest" \
  "$fixture" \
  "d66634ec2fce2305e2cc64e18e55c273dcc802bc82e074f658bef72ad8d53b26" \
  "required regular file is missing or is a symlink: config/testflight-publication-readiness.json"

fixture="$(new_fixture documentation)"
replace_once "$fixture/docs/testflight-publication-readiness.md" \
  'Do not uninstall the app or clear its container.' \
  'Delete and reinstall the app.'
expect_failure "destructive documentation drift" "$fixture" "documented preserved-data install constraint"

fixture="$(new_fixture checklist)"
replace_once "$fixture/docs/release-checklist.md" \
  'bash ./scripts/test-testflight-publication-readiness-audit.sh && bash ./scripts/audit-testflight-publication-readiness.sh' \
  'bash ./scripts/audit-testflight-publication-readiness.sh'
expect_failure "release checklist self-test wiring removed" "$fixture" "release-checklist TestFlight publication gate"

fixture="$(new_fixture run-pr-test)"
replace_once "$fixture/scripts/ci/run-pr.sh" \
  'bash "$WORKSPACE_DIR/scripts/test-testflight-publication-readiness-audit.sh"' \
  'echo "TestFlight publication self-test skipped"'
expect_failure "PR publication self-test removed" "$fixture" "PR TestFlight publication adversarial self-test"

fixture="$(new_fixture run-pr-audit)"
replace_once "$fixture/scripts/ci/run-pr.sh" \
  'bash "$WORKSPACE_DIR/scripts/audit-testflight-publication-readiness.sh"' \
  'echo "TestFlight publication audit skipped"'
expect_failure "PR publication audit removed" "$fixture" "PR TestFlight publication audit"

fixture="$(new_fixture workflow-test)"
replace_once "$fixture/.github/workflows/codecov.yml" \
  'bash ./scripts/test-testflight-publication-readiness-audit.sh' \
  'echo "TestFlight publication self-test skipped"'
expect_failure "CI publication self-test removed" "$fixture" "CI TestFlight publication adversarial self-test"

fixture="$(new_fixture workflow-audit)"
replace_once "$fixture/.github/workflows/codecov.yml" \
  'bash ./scripts/audit-testflight-publication-readiness.sh' \
  'echo "TestFlight publication audit skipped"'
expect_failure "CI publication audit removed" "$fixture" "CI TestFlight publication audit"

if ((CASES != EXPECTED_CASES)); then
  fail "executed $CASES cases; expected exactly $EXPECTED_CASES"
fi

echo "[testflight-publication-test] passed $CASES cases (1 valid + $((CASES - 1)) negative/adversarial)"
