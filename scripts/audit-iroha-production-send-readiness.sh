#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${IROHA_SEND_AUDIT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))}"
MANIFEST="$ROOT_DIR/config/iroha-production-send-readiness.json"
DOC="$ROOT_DIR/docs/iroha-production-send-readiness.md"
UNIVERSAL_DOC="$ROOT_DIR/docs/universal-wallet-v2.md"
RELEASE_CHECKLIST="$ROOT_DIR/docs/release-checklist.md"
TRANSFER_SERVICE="$ROOT_DIR/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
SEND_CONTAINER="$ROOT_DIR/fearless/Modules/Send/SendDependencyContainer.swift"
TRANSFER_TEST="$ROOT_DIR/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
REGISTRY="$ROOT_DIR/fearless/Common/Model/UniversalWalletRegistry.swift"
PROJECT="$ROOT_DIR/fearless.xcodeproj/project.pbxproj"
PODFILE="$ROOT_DIR/Podfile"
EXPECTED_MANIFEST_SHA256="0bbd2155140ea374ffdebe40453f7dd88b99d742de5f4bd64834ccc92fb359b1"

fail() {
  echo "[iroha-send-readiness][ios][error] $*" >&2
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
  [[ -f "$path" && ! -L "$path" ]] || fail "required regular file is missing or is a symlink: $path"
}

require_fixed() {
  local path="$1"
  local marker="$2"
  local label="$3"
  grep -Fq -- "$marker" "$path" || fail "$label is missing from ${path#"$ROOT_DIR/"}"
}

for path in \
  "$MANIFEST" "$DOC" "$UNIVERSAL_DOC" "$RELEASE_CHECKLIST" \
  "$TRANSFER_SERVICE" "$SEND_CONTAINER" "$TRANSFER_TEST" "$REGISTRY" \
  "$PROJECT" "$PODFILE"; do
  require_file "$path"
done

[[ "$(wc -c < "$MANIFEST" | tr -d '[:space:]')" -le 65536 ]] ||
  fail "readiness manifest exceeds 64 KiB"
actual_manifest_sha256="$(sha256_file "$MANIFEST")"
[[ "$actual_manifest_sha256" == "$EXPECTED_MANIFEST_SHA256" ]] ||
  fail "readiness manifest digest mismatch: expected $EXPECTED_MANIFEST_SHA256, got $actual_manifest_sha256"

node - "$MANIFEST" <<'NODE'
const fs = require('node:fs');
let manifest;
try {
  manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
} catch (error) {
  console.error(`[iroha-send-readiness][ios][error] invalid readiness JSON: ${error.message}`);
  process.exit(1);
}
function assert(condition, message) {
  if (!condition) {
    console.error(`[iroha-send-readiness][ios][error] ${message}`);
    process.exit(1);
  }
}
function exactKeys(value, expected, label) {
  assert(value && typeof value === 'object' && !Array.isArray(value), `${label} must be an object`);
  assert(
    JSON.stringify(Object.keys(value).sort()) === JSON.stringify([...expected].sort()),
    `${label} keys drifted`
  );
}

exactKeys(manifest, [
  'schemaVersion', 'platform', 'assessedAt', 'status', 'releaseEnabled',
  'nexusEnabledByDefault', 'upstream', 'artifact', 'integrationAssessment',
  'transactionParity', 'networkReadiness', 'securityBoundary', 'liveEvidence',
  'blocker', 'exitCriteria'
], 'top-level manifest');
assert(manifest.schemaVersion === 2, 'schemaVersion must be 2');
assert(manifest.platform === 'ios', 'platform must be ios');
assert(manifest.assessedAt === '2026-08-19', 'assessment date drifted');
assert(manifest.status === 'blocked', 'status must remain blocked');
assert(manifest.releaseEnabled === false, 'releaseEnabled must remain false');
assert(manifest.nexusEnabledByDefault === false, 'Nexus must remain disabled by default');

assert(manifest.upstream?.repository === 'hyperledger/iroha', 'unexpected upstream repository');
assert(manifest.upstream?.tag === 'v2.0.0-rc.2.1-fearless-mobile-sdk.3', 'unexpected upstream tag');
assert(manifest.upstream?.commit === '4f8cfbdd17aa6a3b049e619f23ec02501e5297b6', 'unexpected upstream commit');

const artifact = manifest.artifact;
assert(artifact?.name === 'NoritoBridge-v2.0.0-rc.2.1-fearless-mobile-sdk.3.xcframework.zip', 'unexpected Apple artifact');
assert(artifact?.sha256 === 'dc944af3dc98d37d349b9f95fe25b9e4a920f095db58adbcccc6354fc28ada4b', 'unexpected Apple artifact digest');
assert(artifact?.bytes === 392660196, 'unexpected Apple artifact size');
assert(artifact?.reviewThresholdBytes === 350000000, 'unexpected Apple review threshold');
assert(artifact.bytes > artifact.reviewThresholdBytes, 'artifact must remain above the recorded review threshold');
assert(artifact.entryCount === 20, 'archive entry count drifted');
assert(artifact.expandedBytes === 1396110349, 'archive expanded size drifted');
assert(artifact.maxEntryBytes === 704780504, 'archive maximum entry size drifted');
assert(artifact.compressionRatio === '3.556', 'archive expansion ratio drifted');
assert(artifact.archiveSafety === 'passed-path-type-encryption-crc-and-bomb-bounds', 'archive safety scope drifted');

const publishedSlices = {
  'ios-arm64': '508b36e1ddc08d3c7488dfbb932d0e37f883908747296b6edab8465efbc3b77c',
  'ios-arm64_x86_64-simulator': 'b4ec44590205d173259f97a424702ace5d1fa70b469df578fc54a68fd2263b56',
  'macos-arm64': '3f13ce287c168b7103b368a67fbf22d1e1d8de0b1b345c8187fae1c206faa60a'
};
const taggedSlices = {
  'ios-arm64': '26bb800e9dce021ef38306caef70dbba7928dd99c6612801fb1bbc520b52b7a9',
  'ios-arm64_x86_64-simulator': 'd0f651e6dc837bff7e92b05c9bf1e3a2988fc6995cabee6e3aaa269a01ecd1b5',
  'macos-arm64': 'd1dc2069532ff760e03ebf66fdd17811d8d7fa520dcd9f9048b61bbcbcffc3e2'
};
assert(JSON.stringify(artifact.publishedSliceSha256) === JSON.stringify(publishedSlices), 'published slice hashes drifted');

const integration = manifest.integrationAssessment;
assert(integration?.appMinimumIOS === '15.0', 'app minimum iOS evidence drifted');
assert(integration?.sdkMinimumIOS === '15.0', 'SDK minimum iOS evidence drifted');
assert(integration?.minimumOSCompatible === true, 'minimum OS compatibility evidence drifted');
assert(integration?.productMinimumOSChangeApproved === true, 'approved product minimum OS change evidence drifted');
assert(integration?.sdkLinkageApproved === false, 'SDK linkage must remain unapproved');
assert(integration?.taggedPackageDelivery === 'path-binary-target-with-symlink-placeholder', 'tagged package delivery evidence drifted');
assert(integration?.taggedPackageResolution === 'fails-without-separate-dist-materialization', 'tagged package resolution blocker drifted');
assert(integration?.taggedCompileToolchain === 'Xcode 26.5 / Swift 6.3.2', 'tagged compile toolchain drifted');
assert(integration?.taggedCompileStatus === 'failed', 'tagged compile failure must remain explicit');
assert(integration?.taggedCompileFailure === 'public-default-arguments-call-private-currentEpochSeconds', 'tagged compile failure reason drifted');
assert(JSON.stringify(integration?.taggedSwiftLoaderExpectedSliceSha256) === JSON.stringify(taggedSlices), 'tagged Swift loader hashes drifted');
assert(integration?.publishedSlicesMatchTaggedLoader === false, 'source/artifact slice mismatch must remain explicit');
for (const key of Object.keys(publishedSlices)) {
  assert(publishedSlices[key] !== taggedSlices[key], `published slice unexpectedly matches tagged loader for ${key}`);
}
assert(integration?.staticLinkDigestVerification === 'not-enforced', 'static-link digest gap must remain explicit');
assert(integration?.binaryScope === 'broad-general-purpose-native-bridge', 'binary review scope drifted');
assert(integration?.licenseOrNoticeBundled === false, 'missing bundled license/notice evidence drifted');
assert(integration?.sbomBundled === false, 'missing SBOM evidence drifted');
assert(integration?.buildProvenanceBundled === false, 'missing build provenance evidence drifted');
assert(integration?.artifactAttestationBundled === false, 'missing artifact attestation evidence drifted');
assert(integration?.cryptographicTagSignaturePresent === false, 'unsigned tag evidence drifted');
assert(integration?.reproducibleSourceToBinaryIdentity === 'not-proven', 'source-to-binary identity gap drifted');

const parity = manifest.transactionParity;
assert(parity?.signedFixtureBytes === 576, 'Swift parity fixture size drifted');
assert(parity?.currentMainCompactEntrypointHash === '9756355bec7ca04a9e95025a0f24296a02118a5bf5989cc9c2cec0612bf76201', 'compact entrypoint hash drifted');
assert(parity?.fixedU64EntrypointHash === 'c072426bffe62e12fc6b94a0c37ecf4eb2a805965964ce999e5183bddc9a1ce7', 'fixed-u64 diagnostic hash drifted');
assert(parity?.taggedSwiftRawFixtureHash === '6cc8aa66faa4b067c44831deaf225d8637ffd6daba05b11857b69a06a6b4279b', 'tagged Swift parity hash drifted');
assert(new Set([
  parity.currentMainCompactEntrypointHash,
  parity.fixedU64EntrypointHash,
  parity.taggedSwiftRawFixtureHash
]).size === 3, 'distinct transaction hash domains unexpectedly collapsed');
assert(parity?.officialTagParityStatus === 'stale-noncanonical', 'official tag parity blocker drifted');
assert(parity?.localCompactCorrectionStatus === 'unpublished-unreviewed-diagnostic-only', 'local correction must not be release evidence');
assert(parity?.liveReceiptParity === 'not-recorded', 'live receipt parity must remain blocked');

const network = manifest.networkReadiness;
assert(network?.routeLabel === 'iroha3-taira', 'Taira route label drifted');
assert(network?.routeLabelCurrentlyPassedAsSigningChainId === true, 'route-label/signing-chain ambiguity must remain explicit');
assert(network?.protocolChainIdMapping === 'not-authoritatively-confirmed', 'protocol chain ID mapping must remain blocked');
assert(network?.fixtureAssetDefinitionId === '61CtjvNd9T3THAR65GsMVHr82Bjc', 'fixture asset definition drifted');
assert(network?.liveTairaNativeXorDefinitionId === '61CtjvNd9T3THAR65GsMVHr82Bjc', 'live Taira XOR definition drifted');
assert(network.fixtureAssetDefinitionId === network.liveTairaNativeXorDefinitionId, 'fixture/live canonical asset alignment drifted');
assert(network?.liveTairaNativeXorScale === 9, 'live Taira XOR scale drifted');
assert(network?.liveTairaNativeXorAliasPresent === true, 'live Taira alias presence drifted');
assert(network?.liveTairaNativeXorAlias === 'xor#sora.universal', 'live Taira canonical alias drifted');
assert(network?.liveTairaAlternateXorDefinitionId === '6TEAJqbb8oEPmLncoNiMRbLEK6tw', 'live Taira alternate XOR definition drifted');
assert(network?.liveTairaAlternateXorAlias === 'xor#universal', 'live Taira alternate XOR alias drifted');
assert(network?.liveTairaAlternateXorScale === null, 'live Taira alternate XOR scale must remain unknown');
assert(network?.canonicalAssetMapping === 'current-live-canonical-with-dynamic-alternate-discovery', 'canonical asset mapping evidence drifted');
assert(network?.authoritativeFeePolicy === 'absent', 'authoritative fee policy must remain blocked');
assert(network?.currentFeeEstimate === 'hardcoded-zero', 'current zero-fee behavior must remain explicit');
assert(network?.liveTairaNodeVersion === '2.0.0-rc.2.0', 'live Taira node version drifted');
assert(network?.liveTairaNodeCommit === '039af2d65e10b773be5031ab8fc07cf27b40e30d', 'live Taira node commit drifted');
assert(network?.sdkToDeployedNodeCompatibility === 'not-proven', 'SDK/deployed-node compatibility must remain blocked');

const security = manifest.securityBoundary;
assert(security?.defaultSigner === 'UnavailableIrohaTransferSigner', 'unexpected security-boundary signer');
assert(security?.secretRequestRepresentation === 'immutable-swift-string', 'secret representation risk drifted');
assert(security?.secretCopiesReliablyZeroizable === false, 'secret zeroization gap must remain explicit');
assert(security?.secretLifecycleReview === 'required-before-sdk-adapter', 'secret lifecycle review gate drifted');
assert(security?.submissionHashPolicy === 'local-hash-preferred-without-receipt-equality-check', 'submission hash-policy gap drifted');
assert(security?.receiptHashEqualityRequired === true, 'receipt hash equality must be required');
assert(security?.acceptedAndFinalizedStatusEvidenceRequired === true, 'accepted/finalized evidence must be required');

for (const [key, value] of Object.entries(manifest.liveEvidence ?? {})) {
  assert(value === 'missing' || (key === 'nexusProductionEndpoint' && value === 'unconfirmed'), `live evidence ${key} must remain unavailable`);
}
assert(Object.keys(manifest.liveEvidence ?? {}).length === 6, 'live evidence key set drifted');
assert(manifest.blocker?.code === 'apple_xcframework_review_and_materialization_required', 'unexpected blocker code');
assert(manifest.blocker?.defaultSigner === 'UnavailableIrohaTransferSigner', 'unexpected blocker signer');
assert(Array.isArray(manifest.exitCriteria) && manifest.exitCriteria.length === 10, 'exactly ten exit criteria are required');
assert(new Set(manifest.exitCriteria).size === manifest.exitCriteria.length, 'exit criteria must be unique');
NODE

require_fixed "$TRANSFER_SERVICE" \
  'signer: IrohaTransferSigning = UnavailableIrohaTransferSigner()' \
  "fail-closed service default"
require_fixed "$TRANSFER_SERVICE" \
  'struct UnavailableIrohaTransferSigner: IrohaTransferSigning' \
  "unavailable signer implementation"
require_fixed "$TRANSFER_SERVICE" \
  'throw TransferServiceError.transferFailed(reason: "Iroha transfer signing codec is unavailable")' \
  "unavailable signer exception"
require_fixed "$TRANSFER_SERVICE" \
  'let mnemonicOrSeed: String' \
  "immutable Swift secret risk marker"
require_fixed "$TRANSFER_SERVICE" \
  'struct IrohaWalletSmokeTransactionMetadata: Equatable' \
  "wallet-smoke immutable metadata snapshot"
require_fixed "$TRANSFER_SERVICE" \
  'let metadata: IrohaTransactionMetadata' \
  "Iroha signing request metadata seam"
require_fixed "$TRANSFER_SERVICE" \
  'func submitNexusWalletSmokeEvidence(' \
  "operator-only Nexus wallet-smoke evidence hook"
for marker in \
  'static let evidenceRoleKey = "evidence_role"' \
  'static let routeGovernanceActionHashKey = "route_governance_action_hash"' \
  'static let walletPlatformKey = "wallet_platform"' \
  'static let walletCommitKey = "wallet_commit"' \
  'untrustedMetadata.count == expectedKeys.count' \
  'Set(untrustedMetadata.keys) == expectedKeys' \
  'untrustedMetadata[evidenceRoleKey] == "wallet-smoke"' \
  'untrustedMetadata[walletPlatformKey] == "ios"' \
  'routeHash != routeHashPrefix + String(repeating: "0", count: 64)' \
  'walletCommit != String(repeating: "0", count: 40)' \
  'private init(snapshot: [String: String])' \
  'chain.chainId == UniversalWalletRegistry.nexus.chainId' \
  'context.signingRequest.network == "nexus"' \
  'context.toriiBaseURL == UniversalWalletRegistry.nexus.toriiBaseURL?.absoluteString'; do
  require_fixed "$TRANSFER_SERVICE" "$marker" "wallet-smoke metadata invariant '$marker'"
done
require_fixed "$TRANSFER_SERVICE" \
  'chainId: network.chainId' \
  "route-label signing-chain ambiguity marker"
require_fixed "$TRANSFER_SERVICE" \
  'return .zero' \
  "unresolved zero-fee marker"
require_fixed "$TRANSFER_SERVICE" \
  'return signedTransfer.transactionHashHex' \
  "local-hash-preferred submission marker"
require_fixed "$TRANSFER_SERVICE" \
  '?? receipt.payload.signedTransactionHash' \
  "receipt signed-transaction hash fallback"
require_fixed "$TRANSFER_SERVICE" \
  '?? receipt.payload.txHash' \
  "receipt transaction hash fallback"
require_fixed "$SEND_CONTAINER" \
  'return IrohaTransferService(wallet: wallet, chain: chainAsset.chain)' \
  "send container fail-closed construction"
require_fixed "$SEND_CONTAINER" \
  'case irohaProductionSendDisabled' \
  "early Iroha production-disable error"
require_fixed "$SEND_CONTAINER" \
  'throw UniversalWalletSendRoutingError.irohaProductionSendDisabled' \
  "early Iroha production-disable guard"
require_fixed "$TRANSFER_TEST" \
  'func testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation()' \
  "default signer fail-closed test"
require_fixed "$TRANSFER_TEST" \
  'func testIrohaTransferServiceRejectsMnemonicMismatchBeforeSignerOrToriiCalls()' \
  "mnemonic/key mismatch adversarial test"
require_fixed "$TRANSFER_TEST" \
  'func testProductionSendDependenciesRejectIrohaBeforeServiceConstruction()' \
  "early production Iroha send-disable test"
for marker in \
  'func testIrohaNexusWalletSmokeEvidenceThreadsExactImmutableMetadataToSigner()' \
  'func testIrohaWalletSmokeMetadataSnapshotDoesNotAliasInputOrReturnedValues()' \
  'func testIrohaNexusWalletSmokeEvidenceRejectsMalformedMetadataBeforeSignerOrTorii()' \
  'func testIrohaWalletSmokeEvidenceRejectsTairaAndNoncanonicalNexusBeforeSignerOrTorii()' \
  'func testIrohaWalletSmokeEvidenceRemainsFailClosedWithUnavailableSigner()'; do
  require_fixed "$TRANSFER_TEST" "$marker" "wallet-smoke adversarial test '$marker'"
done
for marker in \
  'private func makeIrohaTestHistoryEndpoint(_ baseURL: String) -> ChainModel.BlockExplorer' \
  'let endpoint = ChainModel.BlockExplorer(type: "sora", url: url)' \
  'preconditionFailure("Iroha test history endpoint failed to materialize")' \
  'chain.externalApi?.history?.url.absoluteString' \
  'XCTAssertEqual(configurations.count, 12)' \
  'UniversalWalletRegistry.nexus.chainId.uppercased()' \
  '"Nexus registry-id alias"' \
  'https://nexus-proxy.example' \
  'http://minamoto.sora.org' \
  'https://minamoto.sora.org.attacker.invalid' \
  'https://minamoto.sora.org@attacker.invalid' \
  'https://minamoto.sora.org:444' \
  'https://minamoto.sora.org/v1/mcp' \
  'https://minamoto.sora.org?redirect=https://attacker.invalid' \
  'https://minamoto.sora.org#@attacker.invalid' \
  '"https://minamoto.sora.org/",'; do
  require_fixed "$TRANSFER_TEST" "$marker" "materialized Nexus endpoint adversarial fixture '$marker'"
done

node - "$TRANSFER_SERVICE" "$SEND_CONTAINER" <<'NODE'
const fs = require('node:fs');
const transfer = fs.readFileSync(process.argv[2], 'utf8');
const container = fs.readFileSync(process.argv[3], 'utf8');
function fail(message) {
  console.error(`[iroha-send-readiness][ios][error] ${message}`);
  process.exit(1);
}
const routeChecks = container.match(/if isUniversalWalletIroha\(chainAsset[.]chain\) \{/g) ?? [];
const serviceCalls = container.match(/\bIrohaTransferService\s*\(/g) ?? [];
const expectedGuard = `if isUniversalWalletIroha(chainAsset.chain) {
            throw UniversalWalletSendRoutingError.irohaProductionSendDisabled
        }`;
const expectedRoute = `if isUniversalWalletIroha(chainAsset.chain) {
            return IrohaTransferService(wallet: wallet, chain: chainAsset.chain)
        }`;
if (routeChecks.length !== 2 || serviceCalls.length !== 1 ||
    !container.includes(expectedGuard) || !container.includes(expectedRoute)) {
  fail('send routing must contain exactly one audited fail-closed Iroha service construction and one early disable guard');
}
const prepareStart = container.indexOf('func prepareDepencies(chainAsset: ChainAsset)');
const guardIndex = container.indexOf(expectedGuard, prepareStart);
const accountLookup = container.indexOf('guard let accountResponse = wallet.fetch(', prepareStart);
const createStart = container.indexOf('private func createTransferService(', accountLookup);
const routeIndex = container.indexOf(expectedRoute, createStart);
if (prepareStart < 0 || guardIndex < prepareStart || accountLookup < 0 ||
    guardIndex > accountLookup || createStart < accountLookup || routeIndex < createStart) {
  fail('Iroha production-disable guard must precede account lookup and service construction');
}

const requestStart = transfer.indexOf('struct IrohaTransferSigningRequest: Equatable {');
const requestEnd = transfer.indexOf('\n}\n\nstruct IrohaSignedTransfer:', requestStart);
if (requestStart < 0 || requestEnd < 0) fail('Iroha signing request boundary is missing');
const request = transfer.slice(requestStart, requestEnd);
if ((request.match(/let mnemonicOrSeed: String/g) ?? []).length !== 1) {
  fail('signing request must retain exactly one audited immutable Swift secret field while blocked');
}
if ((request.match(/let metadata: IrohaTransactionMetadata/g) ?? []).length !== 1) {
  fail('signing request must retain exactly one audited transaction metadata field');
}

const submitStart = transfer.indexOf('    func submit(transfer: Transfer) async throws -> String {', requestEnd);
const evidenceStart = transfer.indexOf('\n    func submitNexusWalletSmokeEvidence(', submitStart);
const validatedStart = transfer.indexOf('\n    private func submitValidated(', evidenceStart);
const submitEnd = transfer.indexOf('\n    func subscribeForFee(', validatedStart);
if (submitStart < 0 || evidenceStart < 0 || validatedStart < 0 || submitEnd < 0) {
  fail('Iroha ordinary/evidence submission boundary is missing');
}
const ordinarySubmit = transfer.slice(submitStart, evidenceStart);
const evidenceSubmit = transfer.slice(evidenceStart, validatedStart);
const submit = transfer.slice(validatedStart, submitEnd);
if (!ordinarySubmit.includes('submitValidated(transfer: transfer, metadata: .none)')) {
  fail('ordinary Iroha transfers must omit transaction metadata');
}
if (!evidenceSubmit.includes('IrohaWalletSmokeTransactionMetadata.validatedSnapshot(') ||
    !evidenceSubmit.includes('chain.chainId == UniversalWalletRegistry.nexus.chainId') ||
    !evidenceSubmit.includes('let evidenceToriiBaseURL = try Self.toriiBaseURL(') ||
    !evidenceSubmit.includes('evidenceToriiBaseURL == UniversalWalletRegistry.nexus.toriiBaseURL?.absoluteString') ||
    !evidenceSubmit.includes('metadata: .walletSmoke(metadata)')) {
  fail('operator evidence must cross the validated wallet-smoke metadata boundary');
}
const expectedFallback = `return signedTransfer.transactionHashHex
            ?? receipt.payload.signedTransactionHash
            ?? receipt.payload.txHash`;
if ((submit.match(/return signedTransfer[.]transactionHashHex/g) ?? []).length !== 1 || !submit.includes(expectedFallback)) {
  fail('unreviewed submission hash fallback changed without readiness review');
}
if (submit.includes('transactionStatus(') || submit.includes('finalized')) {
  fail('submission finality behavior changed without readiness review');
}
NODE

signing_files="$(
  find "$ROOT_DIR/fearless" -type f -name '*.swift' \
    -exec grep -Il 'IrohaTransferSigning' {} + | sort
)"
[[ "$signing_files" == "$TRANSFER_SERVICE" ]] || {
  printf '%s\n' "$signing_files" >&2
  fail "an Iroha signer implementation appeared outside the audited transfer service"
}

service_call_files="$(
  find "$ROOT_DIR/fearless" -type f -name '*.swift' \
    -exec grep -Il 'IrohaTransferService(' {} + | sort
)"
[[ "$service_call_files" == "$SEND_CONTAINER" ]] || {
  printf '%s\n' "$service_call_files" >&2
  fail "IrohaTransferService construction appeared outside the audited send container"
}

sdk_import_files="$(
  find "$ROOT_DIR/fearless" -type f \( -name '*.swift' -o -name '*.m' -o -name '*.mm' \) \
    -exec grep -EIl '^[[:space:]]*(import[[:space:]]+(IrohaSwift|NoritoBridge)|#import.*NoritoBridge)' {} + | sort || true
)"
[[ -z "$sdk_import_files" ]] || {
  printf '%s\n' "$sdk_import_files" >&2
  fail "IrohaSwift/NoritoBridge was imported into product source before review"
}

node - "$REGISTRY" "$PROJECT" <<'NODE'
const fs = require('node:fs');
const registry = fs.readFileSync(process.argv[2], 'utf8');
const project = fs.readFileSync(process.argv[3], 'utf8');
function fail(message) {
  console.error(`[iroha-send-readiness][ios][error] ${message}`);
  process.exit(1);
}
function networkBlock(name) {
  const start = registry.indexOf(`static let ${name} = IrohaNetwork(`);
  const end = registry.indexOf('\n    )', start);
  if (start < 0 || end < 0) fail(`${name} registry block is missing`);
  return registry.slice(start, end);
}
const taira = networkBlock('taira');
const nexus = networkBlock('nexus');
if (!taira.includes('chainId: "iroha3-taira"')) fail('Taira route label drifted without readiness review');
if (!nexus.includes('enabledByDefault: false')) fail('Nexus registry default is not provably disabled');

const appMarkers = [...project.matchAll(/INFOPLIST_FILE = fearless\/Info[.]plist;/g)];
const appBlocks = appMarkers.map((marker) => {
  const start = project.lastIndexOf('buildSettings = {', marker.index);
  const end = project.indexOf('\n\t\t\t};', marker.index);
  if (start < 0 || end < 0) fail('Fearless app build-settings boundary is malformed');
  return project.slice(start, end);
});
if (appBlocks.length !== 3 || appBlocks.some((block) => !block.includes('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'))) {
  fail('Fearless app deployment target must remain exactly iOS 15.0');
}
NODE

require_fixed "$PODFILE" \
  "config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'" \
  "CocoaPods iOS 15.0 deployment target"

if grep -Eq 'repositoryURL = ".*(hyperledger/iroha|IrohaSwift)|productName = (IrohaSwift|NoritoBridge)' "$PROJECT"; then
  fail "IrohaSwift/NoritoBridge was added to the Xcode dependency graph before review"
fi
if grep -Eq '(^|[[:space:]"/])(IrohaSwift|NoritoBridge)([[:space:]"/,]|$)|hyperledger/iroha' "$PODFILE"; then
  fail "IrohaSwift/NoritoBridge was added to CocoaPods before review"
fi

dependency_manifest_hit="$({
  find "$ROOT_DIR" -path "$ROOT_DIR/Pods" -prune -o -path "$ROOT_DIR/build" -prune -o \
    -type f \( -name 'Package.swift' -o -name 'Cartfile' -o -name '*.podspec' \) -print0
} | xargs -0 grep -EIl '(hyperledger/iroha|IrohaSwift|NoritoBridge)' 2>/dev/null | sort || true)"
[[ -z "$dependency_manifest_hit" ]] || {
  printf '%s\n' "$dependency_manifest_hit" >&2
  fail "an Iroha SDK dependency manifest appeared before review"
}

local_binary="$(
  find "$ROOT_DIR" \
    -path "$ROOT_DIR/.git" -prune -o \
    -path "$ROOT_DIR/Pods" -prune -o \
    -path "$ROOT_DIR/build" -prune -o \
    -path "$ROOT_DIR/DerivedData" -prune -o \
    -path "$ROOT_DIR/SourcePackages" -prune -o \
    \( -type f -o -type d \) \
    \( -name 'NoritoBridge*.zip' -o -name 'NoritoBridge*.a' -o \
       -name 'NoritoBridge*.framework' -o -name 'NoritoBridge*.xcframework' -o \
       -name 'libconnect_norito_bridge.a' -o -name 'libconnect_norito_bridge.dylib' \) \
    -print | sort
)"
[[ -z "$local_binary" ]] || {
  printf '%s\n' "$local_binary" >&2
  fail "Iroha SDK/native binary material exists in the release tree before review"
}

tracked_binary="$(git -C "$ROOT_DIR" ls-files | grep -E '(^|/)(NoritoBridge.*([.]zip|[.]a|[.]framework|[.]xcframework)|libconnect_norito_bridge([.]a|[.]dylib))($|/)' || true)"
[[ -z "$tracked_binary" ]] || {
  printf '%s\n' "$tracked_binary" >&2
  fail "Iroha SDK/native binary material was tracked before review"
}

for marker in \
  'BLOCKED / fail closed' \
  'v2.0.0-rc.2.1-fearless-mobile-sdk.3' \
  'dc944af3dc98d37d349b9f95fe25b9e4a920f095db58adbcccc6354fc28ada4b' \
  '1396110349' \
  '704780504' \
  'iOS `15.0`' \
  'public default arguments' \
  'None matches the corresponding published release slice' \
  '9756355bec7ca04a9e95025a0f24296a02118a5bf5989cc9c2cec0612bf76201' \
  'c072426bffe62e12fc6b94a0c37ecf4eb2a805965964ce999e5183bddc9a1ce7' \
  '6cc8aa66faa4b067c44831deaf225d8637ffd6daba05b11857b69a06a6b4279b' \
  'unpublished correction' \
  '61CtjvNd9T3THAR65GsMVHr82Bjc' \
  '6TEAJqbb8oEPmLncoNiMRbLEK6tw' \
  '039af2d65e10b773be5031ab8fc07cf27b40e30d' \
  'Swift `String`' \
  'Nexus wallet-smoke metadata boundary' \
  '"evidence_role": "wallet-smoke"' \
  '"route_governance_action_hash": "sha256:<64 lowercase nonzero hex characters>"' \
  '"wallet_platform": "ios"' \
  '"wallet_commit": "<40 lowercase nonzero git hex characters>"' \
  'Missing, extra, case-shifted, control-character, non-ASCII, malformed, and' \
  'accepted plus' \
  'funded Taira broadcast' \
  'apple_xcframework_review_and_materialization_required' \
  'does **not** make Iroha send production-ready'; do
  require_fixed "$DOC" "$marker" "readiness evidence marker '$marker'"
done

require_fixed "$UNIVERSAL_DOC" \
  'Iroha `features: ["transfer"]` is capability metadata, not a production-send' \
  "Universal Wallet non-enablement statement"
require_fixed "$UNIVERSAL_DOC" \
  '`config/iroha-production-send-readiness.json`' \
  "Universal Wallet readiness manifest reference"
require_fixed "$UNIVERSAL_DOC" \
  'The iOS Nexus operator evidence seam snapshots an exact four-string' \
  "Universal Wallet exact wallet-smoke metadata statement"

for marker in \
  'enforced iOS 15 product minimum' \
  'canonical compact transaction-hash parity' \
  'authoritative protocol chain ID' \
  'zeroizable secret-lifecycle boundary' \
  'exact local/Torii receipt-hash equality' \
  'funded Taira and Nexus broadcast evidence' \
  'local unpublished upstream correction is diagnostic only'; do
  require_fixed "$RELEASE_CHECKLIST" "$marker" "release checklist Iroha gate '$marker'"
done

echo "[iroha-send-readiness][ios] 15/15 platform alignment, source/binary, parity, protocol, key-lifecycle, receipt, live-evidence, and fail-closed invariants passed."
