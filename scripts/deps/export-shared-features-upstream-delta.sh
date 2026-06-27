#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
OUT_DIR="${2:-$ROOT/build/shared-features-upstream-delta}"

AUDIT_SCRIPT="$ROOT/scripts/deps/audit-shared-features-delta-report.sh"
NATIVE_EXPORT_SCRIPT="$ROOT/scripts/deps/export-native-crypto-upstream-delta.sh"

fail() {
  echo "[export-shared-features-upstream-delta] $1" >&2
  exit 1
}

[[ -x "$AUDIT_SCRIPT" ]] || fail "Missing executable delta report audit: $AUDIT_SCRIPT"
[[ -x "$NATIVE_EXPORT_SCRIPT" ]] || fail "Missing executable native crypto export script: $NATIVE_EXPORT_SCRIPT"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

REPORT_FILE="$OUT_DIR/shared-features-delta-report.json"
NATIVE_OUT_DIR="$OUT_DIR/native-crypto"

"$AUDIT_SCRIPT" "$ROOT" --write-report "$REPORT_FILE" >/dev/null
"$NATIVE_EXPORT_SCRIPT" "$ROOT" "$NATIVE_OUT_DIR" >/dev/null

node - "$REPORT_FILE" "$OUT_DIR/README.md" "$OUT_DIR/handoff-manifest.json" <<'NODE'
const fs = require('fs');
const crypto = require('crypto');

const reportPath = process.argv[2];
const readmePath = process.argv[3];
const manifestPath = process.argv[4];
const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));

function sha256(path) {
  return crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex');
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

assert(report.schemaVersion === 1, 'delta report schemaVersion must be 1');
assert(Array.isArray(report.carriedDeltas) && report.carriedDeltas.length > 0, 'delta report must contain carriedDeltas');
assert(report.removalReadiness?.status === 'blocked', 'removalReadiness.status must remain blocked for handoff');

const deltaLines = report.carriedDeltas.map((item) => `- ${item.id}: ${item.label}`);
const blockerLines = report.removalReadiness.blockers.map((item) => `- ${item}`);

fs.writeFileSync(
  readmePath,
  [
    '# Shared Features Upstream Delta',
    '',
    'This directory is the release-review handoff for the pinned `shared-features-spm` delta still carried by the wallet repo.',
    '',
    `Pinned shared-features-spm revision: \`${report.sharedFeaturesRevision}\``,
    '',
    '## Contents',
    '',
    '- `shared-features-delta-report.json`: machine-readable inventory of every carried delta, removal blockers, and native crypto template hashes.',
    '- `native-crypto/`: portable native-crypto package-state export for upstreaming or vendoring.',
    '- `handoff-manifest.json`: deterministic checksum manifest for this handoff bundle.',
    '',
    '## Carried Deltas',
    '',
    ...deltaLines,
    '',
    '## Removal Blockers',
    '',
    ...blockerLines,
    '',
    '## Exit Condition',
    '',
    report.exitCondition,
    ''
  ].join('\n')
);

const files = [
  'shared-features-delta-report.json',
  'native-crypto/README.md',
  'native-crypto/Sources/IrohaCrypto/include/module.modulemap',
  'native-crypto/Sources/IrohaCrypto/include/IrohaCrypto-umbrella.h',
  'native-crypto/Sources/IrohaCrypto/IrohaCrypto-umbrella.h',
  'native-crypto/IrohaCrypto.linker-settings.swiftfrag',
  'README.md'
];

const baseDir = manifestPath.replace(/\/handoff-manifest\.json$/, '');
const manifest = {
  schemaVersion: 1,
  sharedFeaturesRevision: report.sharedFeaturesRevision,
  removalReadinessStatus: report.removalReadiness.status,
  carriedDeltaCount: report.carriedDeltas.length,
  files: files.map((relativePath) => {
    const absolutePath = `${baseDir}/${relativePath}`;
    assert(fs.existsSync(absolutePath), `missing handoff file: ${relativePath}`);
    return {
      path: relativePath,
      sha256: sha256(absolutePath)
    };
  })
};

fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
NODE

echo "[export-shared-features-upstream-delta] Exported shared-features upstream delta to $OUT_DIR"
