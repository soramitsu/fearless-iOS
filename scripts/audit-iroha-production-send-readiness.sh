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
TORII_CLIENT="$ROOT_DIR/fearless/Common/Model/IrohaToriiClient.swift"
TORII_CONTRACT="$ROOT_DIR/fearless/Common/Model/IrohaToriiContract.swift"
TORII_TEST="$ROOT_DIR/fearlessTests/IrohaToriiClientTests.swift"
TORII_CONTRACT_TEST="$ROOT_DIR/fearlessTests/IrohaToriiContractTests.swift"
HISTORY_SOURCE="$ROOT_DIR/fearless/CoreLayer/OperationFactory/BlockExplorer/History/Main/IrohaHistoryOperationFactory.swift"
HISTORY_TEST="$ROOT_DIR/fearlessTests/IrohaHistoryOperationFactoryTests.swift"
BALANCE_SOURCE="$ROOT_DIR/fearless/ApplicationLayer/Services/Balance/RemoteSubscription/AccountInfoRemoteService.swift"
BALANCE_TEST="$ROOT_DIR/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
ADDRESS_RESOLVER="$ROOT_DIR/fearless/Common/Model/UniversalWalletAccountAddressResolver.swift"
ADDRESS_TEST="$ROOT_DIR/fearlessTests/UniversalWalletAccountAddressResolverTests.swift"
META_ACCOUNT_MAPPER="$ROOT_DIR/fearless/Common/Storage/EntityToModel/MetaAccountMapper.swift"
META_ACCOUNT_MAPPER_TEST="$ROOT_DIR/fearlessTests/Common/Storage/MetaAccountMapperTests.swift"
MIGRATION_SOURCE="$ROOT_DIR/fearless/Common/Model/UniversalWalletMigrationContract.swift"
MIGRATION_TEST="$ROOT_DIR/fearlessTests/UniversalWalletMigrationContractTests.swift"
REGISTRY="$ROOT_DIR/fearless/Common/Model/UniversalWalletRegistry.swift"
PROJECT="$ROOT_DIR/fearless.xcodeproj/project.pbxproj"
PODFILE="$ROOT_DIR/Podfile"
EXPECTED_MANIFEST_SHA256="3f1d4f8ca65d86abd86c3ac28f7142d24702472b07266477585bc70000bb68a4"

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
  "$TRANSFER_SERVICE" "$SEND_CONTAINER" "$TRANSFER_TEST" "$TORII_CLIENT" "$TORII_CONTRACT" "$TORII_TEST" \
  "$TORII_CONTRACT_TEST" \
  "$HISTORY_SOURCE" "$HISTORY_TEST" "$BALANCE_SOURCE" "$BALANCE_TEST" \
  "$ADDRESS_RESOLVER" "$ADDRESS_TEST" "$META_ACCOUNT_MAPPER" "$META_ACCOUNT_MAPPER_TEST" \
  "$MIGRATION_SOURCE" "$MIGRATION_TEST" "$REGISTRY" \
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
assert(manifest.assessedAt === '2026-08-23', 'assessment date drifted');
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
assert(integration?.appMinimumIOS === '14.1', 'app minimum iOS evidence drifted');
assert(integration?.sdkMinimumIOS === '15.0', 'SDK minimum iOS evidence drifted');
assert(integration?.minimumOSCompatible === false, 'minimum OS mismatch must remain explicit');
assert(integration?.productMinimumOSChangeApproved === false, 'product minimum OS change must remain unapproved');
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
assert(network?.protocolChainId === 'fc56984b-2be7-431d-840e-21514d1883f0', 'canonical Taira chain id drifted');
assert(network?.protocolChainIdMapping === 'canonical-first-release-profile-configured', 'protocol chain ID mapping drifted');
assert(network?.canonicalTairaNativeXorDefinitionId === '6TEAJqbb8oEPmLncoNiMRbLEK6tw', 'canonical Taira XOR definition drifted');
assert(network?.canonicalTairaNativeXorScale === 9, 'canonical Taira XOR scale drifted');
assert(network?.canonicalTairaNativeXorSymbol === 'XOR', 'canonical Taira XOR symbol drifted');
assert(network?.canonicalTairaNativeXorDecimals === 9, 'canonical Taira XOR decimals drifted');
assert(network?.liveTairaObservedNativeXorScale === null, 'pre-rollout live Taira XOR scale observation drifted');
assert(network?.canonicalAssetMapping === 'exact-base58-with-torii-definition-validation', 'canonical asset mapping policy drifted');
assert(network?.fanoutReadPolicy === 'require-six-complete-fanout-headers-reject-partial-or-malformed', 'fanout read policy drifted');
assert(network?.authoritativeFeePolicy === 'absent', 'authoritative fee policy must remain blocked');
assert(network?.currentFeeEstimate === 'fail-closed-typed-error-authoritative-policy-unavailable', 'fee estimation must remain fail closed');
assert(JSON.stringify(network?.liveTairaObservation) === JSON.stringify({
  observedAt: '2026-08-23',
  buildCommit: '7efcc118eb50e3369d004d092f9b9d0b4d31ac52',
  blocks: 6,
  peers: 2,
  chainProgressStalenessApproxMinutes: 41,
  chainIdReported: null,
  statusExposesAbsoluteManifestPath: true,
  canonicalXorFanoutAttempted: 5,
  canonicalXorFanoutSucceeded: 1,
  canonicalXorScale: null,
  alternateScaleNineDefinitionPrefixObserved: '61Ct',
  committedValidatorDnsTotal: 4,
  committedValidatorDnsResolved: 0,
  deploymentAuthority: 'workspace-root-live-gate'
}), 'live Taira degraded observation drifted');
assert(network?.sdkToDeployedNodeCompatibility === 'not-proven', 'SDK/deployed-node compatibility must remain blocked');

const security = manifest.securityBoundary;
assert(security?.defaultSigner === 'UnavailableIrohaTransferSigner', 'unexpected security-boundary signer');
assert(security?.secretRequestRepresentation === 'immutable-swift-string', 'secret representation risk drifted');
assert(security?.secretCopiesReliablyZeroizable === false, 'secret zeroization gap must remain explicit');
assert(security?.secretLifecycleReview === 'required-before-sdk-adapter', 'secret lifecycle review gate drifted');
assert(security?.submissionHashPolicy === 'require-local-top-level-transaction-receipt-final-hash-equality-and-applied-finality-via-mcp-submit-and-wait', 'submission hash policy drifted');
assert(security?.canonicalHashFormat === '[0-9a-f]{63}[13579bdf]', 'canonical Iroha hash format drifted');
assert(security?.allSubmissionHashesEqualityRequired === true, 'all submit-and-wait hashes must match locally');
assert(security?.appliedTerminalRequired === true, 'Applied terminal status must remain mandatory');
assert(security?.acceptedAndFinalizedStatusEvidenceRequired === true, 'accepted/finalized evidence must be required');

for (const [key, value] of Object.entries(manifest.liveEvidence ?? {})) {
  assert(value === 'missing' || (key === 'nexusProductionEndpoint' && value === 'unconfirmed'), `live evidence ${key} must remain unavailable`);
}
assert(Object.keys(manifest.liveEvidence ?? {}).length === 6, 'live evidence key set drifted');
assert(manifest.blocker?.code === 'apple_xcframework_review_and_materialization_required', 'unexpected blocker code');
assert(manifest.blocker?.defaultSigner === 'UnavailableIrohaTransferSigner', 'unexpected blocker signer');
assert(Array.isArray(manifest.exitCriteria) && manifest.exitCriteria.length === 11, 'exactly eleven exit criteria are required');
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
  'throw IrohaTransferFeeError.authoritativePolicyUnavailable(' \
  "typed fee-unavailable fail-closed behavior"
for marker in \
  'guard let localHash = Self.canonicalTransactionHash(signedTransfer.transactionHashHex)' \
  'toriiClient.submitTransactionAndWait(' \
  'expectedHash: localHash' \
  'Self.canonicalTransactionHash(outcome.hash)' \
  'Self.canonicalTransactionHash(outcome.transactionHash)' \
  'Self.canonicalTransactionHash(outcome.submit.body.payload.entrypointHash)' \
  'Self.canonicalTransactionHash(outcome.finalStatus.body.hash)' \
  '[outcomeHash, transactionHash, receiptHash, finalHash].allSatisfy({ $0 == localHash })' \
  'outcome.terminalKind == .applied' \
  'outcome.finalStatus.body.status.kind == .applied' \
  'case let .rejected(message):' \
  'case let .expired(message):' \
  'case let .timeout(message):' \
  '^[0-9a-f]{63}[13579bdf]$'; do
  require_fixed "$TRANSFER_SERVICE" "$marker" "MCP submit-and-wait invariant '$marker'"
done
for marker in \
  'unavailable <= failed - denied' \
  'notFound <= failed - denied - unavailable'; do
  require_fixed "$TORII_CONTRACT" "$marker" "overflow-safe fanout invariant '$marker'"
done
for marker in \
  'scheme == "https" || (scheme == "http" && isLocal)' \
  'url.user == nil' \
  'url.password == nil' \
  'url.query == nil' \
  'url.fragment == nil'; do
  require_fixed "$TORII_CONTRACT" "$marker" "safe Iroha base URL invariant '$marker'"
done
require_fixed "$TORII_CONTRACT_TEST" \
  'ftp://localhost' \
  "non-HTTP localhost URL adversarial test"
require_fixed "$TORII_CONTRACT" \
  'let contentType: String' \
  "required nested MCP content type"
require_fixed "$TORII_CONTRACT" \
  'let headers: [String: String]' \
  "required nested MCP fanout headers"
if grep -Fq -- 'let contentType: String?' "$TORII_CONTRACT"; then
  fail "nested MCP content type must not be optional"
fi
if grep -Fq -- 'let headers: [String: String]?' "$TORII_CONTRACT"; then
  fail "nested MCP fanout headers must not be optional"
fi
require_fixed "$TORII_CONTRACT" \
  'let jsonrpc: String?' \
  "missing JSON-RPC version must remain observable"
require_fixed "$TORII_CONTRACT" \
  'guard matches(hash, "^[0-9a-f]{63}[13579bdf]$")' \
  "canonical transaction-status hash routing"
require_fixed "$TORII_CONTRACT" \
  'assetDefinitionId == assetDefinitionId.trimmingCharacters(in: .whitespacesAndNewlines)' \
  "exact asset-definition identifier routing"
require_fixed "$TRANSFER_SERVICE" \
  'guard value.range(of: "^[0-9a-f]{63}[13579bdf]$", options: .regularExpression) != nil' \
  "canonical transfer-service transaction hashes"
for marker in \
  '"name": .string("iroha.transactions.submit_and_wait")' \
  '"body_base64": .string(noritoBytes.base64EncodedString())' \
  '"hash": .string(canonicalExpectedHash)' \
  '"terminal_statuses": .array([.string("Applied")])' \
  'canonicalTransactionHash(outcome.hash) == canonicalExpectedHash' \
  'canonicalTransactionHash(outcome.transactionHash) == canonicalExpectedHash' \
  'canonicalTransactionHash(outcome.submit.body.payload.entrypointHash) == canonicalExpectedHash' \
  'canonicalTransactionHash(outcome.finalStatus.body.hash) == canonicalExpectedHash' \
  'outcome.terminalKind == .applied' \
  'outcome.finalStatus.body.status.kind == .applied' \
  '"x-iroha-fanout-routes-attempted"' \
  '"x-iroha-fanout-routes-succeeded"' \
  '"x-iroha-fanout-routes-failed"' \
  '"x-iroha-fanout-routes-denied"' \
  '"x-iroha-fanout-routes-unavailable"' \
  '"x-iroha-fanout-routes-not-found"' \
  'completeRoutedData(try await transport.performResponse' \
  'completeMCPData(try await transport.performResponse' \
  'let headers = try normalizedResponseHeaders(response.headers)' \
  'try requireJSONContentType(headers)' \
  'isJSONMediaType(outcome.submit.contentType)' \
  'throw IrohaToriiReadError.malformedResponseHeaders' \
  'let hasExactlyOnePayload = (response.result == nil) != (response.error == nil)' \
  'response.jsonrpc == "2.0"' \
  'response.id == .string(request.id)' \
  'throw IrohaToriiReadError.invalidJSONRPCResponse' \
  'guard value.range(' \
  'completionHandler(nil)' \
  'transport: IrohaToriiHTTPTransport = IrohaNoRedirectHTTPTransport()' \
  'rawValue.range(of: "^(0|[1-9][0-9]*)$", options: .regularExpression)' \
  '^[0-9a-f]{63}[13579bdf]$'; do
  require_fixed "$TORII_CLIENT" "$marker" "Torii strict read/write invariant '$marker'"
done
for marker in \
  'case inexactAmount(assetId: String, baseUnits: String, precision: Int)' \
  'amount.toSubstrateAmount(precision: Int16(precision)) == transfer.amount' \
  'rejectingAliases: ["transactionStatus", "status"]' \
  'guard transactionStatus == "Committed"' \
  'let outgoing = sourceAccount == accountAddress' \
  'definitions.countMode == IrohaToriiCountMode.bounded.rawValue' \
  'body.hasExactKeys(historyPageKeys)' \
  'pagination.hasExactKeys(paginationKeys)' \
  'page == Int64(requestedPage)' \
  'totalPages == calculatedTotalPages' \
  'let box = self["box"]?.objectValue' \
  'mode["mode"] == .string("Atomic")' \
  'mode["value"] == .null' \
  'legId.utf8.count <= maxIrohaBatchLegIdLength' \
  'private let maxIrohaQuantity = (BigUInt(1) << 511) - 1' \
  'duplicate_history_identity'; do
  require_fixed "$HISTORY_SOURCE" "$marker" "exact Iroha history amount invariant '$marker'"
done
for marker in \
  'func testLargeValidIrohaQuantityFailsInsteadOfDisplayingRoundedAmount()' \
  'func testPaddedWalletAssetDefinitionFailsBeforeHistoryQueries()' \
  'func testRequiresExactAtomicBatchModeAndStableCanonicalIdentities()' \
  'func testRejectsNoncanonicalNumericSpellingsAndValuesOutsideIrohaDomain()' \
  'func testRejectsMalformedCanonicalDtoFieldsAndRustRawIdentifierAlias()' \
  'func testRequiresCoherentExactPaginationAndSnapshotBoundContext()'; do
  require_fixed "$HISTORY_TEST" "$marker" "exact Iroha history amount adversarial test '$marker'"
done
require_fixed "$HISTORY_TEST" \
  'func testRejectsAssetSourcesThatOnlyContainWalletAddressAsSubstring()' \
  "exact Iroha history account-binding adversarial test"
require_fixed "$HISTORY_TEST" \
  'func testRejectsCaseMutatedNoncanonicalI105SourceAccounts()' \
  "canonical I105 history account-binding adversarial test"
require_fixed "$HISTORY_TEST" \
  'func testRejectsEveryNoncanonicalCommittedTransactionStatus()' \
  "exact committed Iroha history status adversarial test"
require_fixed "$HISTORY_TEST" \
  'func testRejectsLegacyAndAmbiguousTopLevelHistoryFieldAliases()' \
  "canonical Iroha history field-name adversarial test"
for marker in \
  'limit: IrohaToriiRoutes.maxLimit' \
  'offset: 0' \
  'countMode: .bounded' \
  'definitions.countMode == IrohaToriiCountMode.bounded.rawValue' \
  'response.countMode == IrohaToriiCountMode.bounded.rawValue' \
  'guard item.accountID == address' \
  'guard item.assetID == nil' \
  'IrohaToriiRoutes.normalizeAssetDefinitionId(item.asset)' \
  'IrohaToriiRoutes.normalizeAccountAssetScope(scope)' \
  'seenAssetScopes.insert("\(canonicalAsset)\u{0}\(canonicalScope)").inserted' \
  'let maxBalanceInPlanks = maxIrohaNumeric * scaleFactor' \
  'value <= maxBalanceInPlanks - total'; do
  require_fixed "$BALANCE_SOURCE" "$marker" "strict Iroha balance invariant '$marker'"
done
for marker in \
  'func testFetchAccountInfosRequiresCanonicalBoundedIrohaAccountAssets()' \
  'func testFetchAccountInfosRejectsPaddedIrohaAssetDefinitions()' \
  'func testFetchAccountInfosAcceptsIrohaNumericMaximumAtWalletPrecision()' \
  'func testFetchAccountInfosRejectsDuplicateIrohaAssetScopeRows()' \
  'func testFetchAccountInfosRejectsIrohaCrossScopeSumAbovePrecisionAdjustedMaximum()' \
  'func testFetchAccountInfosNeverRoutesNoncanonicalIrohaIdentitiesToTorii()' \
  'func testFetchAccountInfosRejectsNonBoundedIrohaDefinitionSnapshot()'; do
  require_fixed "$BALANCE_TEST" "$marker" "Iroha balance adversarial test '$marker'"
done
for marker in \
  'static func isNonCanonicalIrohaIdentity(_ chainId: String) -> Bool' \
  'let trimmedChainId = chainId.trimmingCharacters(in: .whitespacesAndNewlines)' \
  'trimmedChainId.caseInsensitiveCompare(UniversalWalletRegistry.taira.id) == .orderedSame' \
  'trimmedChainId.caseInsensitiveCompare(UniversalWalletRegistry.nexus.id) == .orderedSame' \
  'trimmedChainId.caseInsensitiveCompare(UniversalWalletRegistry.taira.chainId) == .orderedSame' \
  'trimmedChainId.caseInsensitiveCompare(UniversalWalletRegistry.nexus.chainId) == .orderedSame' \
  'trimmedChainId.caseInsensitiveCompare("iroha3-taira") == .orderedSame' \
  'if exactIrohaNetwork(for: requestedChainId) != nil {' \
  'return storedChainId == requestedChainId' \
  'case UniversalWalletRegistry.taira.chainId:' \
  'case UniversalWalletRegistry.nexus.chainId:'; do
  require_fixed "$ADDRESS_RESOLVER" "$marker" "canonical Iroha account identity invariant '$marker'"
done
for marker in \
  '!UniversalWalletChainAccountSupport.isNonCanonicalIrohaIdentity(chainId)' \
  'func testSingleNoncanonicalIrohaStoredRowIsQuarantined()' \
  'func testSingleWhitespaceWrappedIrohaStoredRowIsQuarantined()'; do
  if [[ "$marker" == func* ]]; then
    require_fixed "$META_ACCOUNT_MAPPER_TEST" "$marker" "stored Iroha identity quarantine test"
  else
    require_fixed "$META_ACCOUNT_MAPPER" "$marker" "stored Iroha identity quarantine invariant"
  fi
done
for marker in \
  'chainAccount(matchingExactly: Self.tairaChainIds)' \
  'chainAccount(matchingExactly: Self.nexusChainIds)' \
  'static let tairaChainIds: Set<String> = [' \
  'static let nexusChainIds: Set<String> = ['; do
  require_fixed "$MIGRATION_SOURCE" "$marker" "canonical Iroha migration invariant '$marker'"
done
if grep -Fq -- 'UniversalWalletRegistry.taira.id' "$MIGRATION_SOURCE" || \
   grep -Fq -- 'UniversalWalletRegistry.nexus.id' "$MIGRATION_SOURCE"; then
  fail "Iroha registry aliases must not be migration identities"
fi
for marker in \
  'if UniversalWalletChainAccountSupport.isNonCanonicalIrohaProfile(chainAsset.chain) {' \
  'throw UniversalWalletSendRoutingError.unsupported(chainId: chainAsset.chain.chainId)' \
  'case UniversalWalletRegistry.taira.chainId,' \
  'UniversalWalletRegistry.nexus.chainId:'; do
  require_fixed "$SEND_CONTAINER" "$marker" "canonical Iroha send-route invariant '$marker'"
done
require_fixed "$HISTORY_TEST" \
  'func testAssemblyRoutesOnlyCanonicalIrohaChainIdentitiesToIrohaHistoryFactory()' \
  "canonical Iroha history-route adversarial test"
require_fixed "$ADDRESS_TEST" \
  'func testIrohaAddressResolutionRejectsAliasesCaseMutationsAndUnknownIdentifiers()' \
  "canonical Iroha address adversarial test"
require_fixed "$ADDRESS_TEST" \
  'func testIrohaAddressResolutionRejectsWhitespaceWrappedKnownIdentities()' \
  "whitespace-wrapped Iroha address adversarial test"
require_fixed "$MIGRATION_TEST" \
  'func testBuilderRejectsNoncanonicalIrohaChainIdentities()' \
  "canonical Iroha migration adversarial test"
for marker in \
  'func testPrepareDependenciesRejectsNoncanonicalIrohaIdentities()' \
  'func testIrohaTransferServiceRejectsNoncanonicalChainIdentitiesBeforeSignerOrTorii()' \
  'func testIrohaTransferServiceRejectsNonCanonicalHashSpellingsWithoutNormalization()'; do
  require_fixed "$TRANSFER_TEST" "$marker" "canonical Iroha send adversarial test '$marker'"
done
for marker in \
  'func testRejectsDegradedNestedSubmitAndWaitFanout()' \
  'func testRejectsIncompleteSixHeaderFanoutContract()' \
  'func testRejectsSuccessfulRoutedReadsWithoutFanoutEvidence()' \
  'func testRejectsOverflowingFanoutCountersWithoutTrapping()' \
  'func testAcceptsMCPTransportWithoutOuterFanoutWhenNestedRoutesAreComplete()' \
  'func testRejectsNonJSONAndCaseCollidingOuterSuccessfulResponses()' \
  'func testRejectsNonJSONAndCaseCollidingNestedRouteMetadata()' \
  'func testIrohaRedirectDelegateRefusesCrossOriginRedirect()' \
  'func testRejectsAnySubmitAndWaitHashThatDiffersFromLocalExpectedHash()' \
  'func testRejectsJSONRPCResponsesThatAreNotExactlyBoundToTheRequest()' \
  'func testRejectsNonCanonicalTransactionHashSpellingsWithoutNormalization()' \
  'func testRejectsMatchingButNonAppliedSubmitAndWaitFinality()' \
  'func testClassifiesSubmitAndWaitRejectedExpiredAndTimeoutToolErrors()'; do
  require_fixed "$TORII_TEST" "$marker" "Torii adversarial test '$marker'"
done
require_fixed "$TORII_CONTRACT_TEST" \
  'for nonCanonicalHash in ["0x\(Self.hash)", Self.hash.uppercased(), " \(Self.hash)"]' \
  "non-canonical transaction-status hash adversarial test"
require_fixed "$TORII_CONTRACT_TEST" \
  'func testRejectsPaddedAssetDefinitionIdentifiersWithoutCanonicalizing()' \
  "padded asset-definition identifier adversarial test"
require_fixed "$SEND_CONTAINER" \
  'return IrohaTransferService(wallet: wallet, chain: chainAsset.chain)' \
  "send container fail-closed construction"
require_fixed "$TRANSFER_TEST" \
  'func testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation()' \
  "default signer fail-closed test"
require_fixed "$TRANSFER_TEST" \
  'func testIrohaTransferServiceFeeEstimationFailsClosedWithoutAuthoritativePolicy()' \
  "fee-unavailable fail-closed test"
require_fixed "$TRANSFER_TEST" \
  'func testIrohaTransferServiceRejectsMnemonicMismatchBeforeSignerOrToriiCalls()' \
  "mnemonic/key mismatch adversarial test"
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
const expectedRoute = `if isUniversalWalletIroha(chainAsset.chain) {
            return IrohaTransferService(wallet: wallet, chain: chainAsset.chain)
        }`;
if (routeChecks.length !== 1 || serviceCalls.length !== 1 || !container.includes(expectedRoute)) {
  fail('send routing must contain exactly one audited fail-closed Iroha service construction');
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
if (!submit.includes('canonicalTransactionHash(signedTransfer.transactionHashHex)') ||
    !submit.includes('submitTransactionAndWait(') ||
    !submit.includes('expectedHash: localHash') ||
    !submit.includes('[outcomeHash, transactionHash, receiptHash, finalHash].allSatisfy') ||
    !submit.includes('outcome.terminalKind == .applied') ||
    !submit.includes('outcome.finalStatus.body.status.kind == .applied')) {
  fail('submission must require all MCP hashes to equal local and reach Applied finality');
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
if (!registry.includes('static let tairaChainId = "fc56984b-2be7-431d-840e-21514d1883f0"') ||
    !taira.includes('chainId: tairaChainId') ||
    !taira.includes('id: tairaXorAssetDefinitionId') ||
    !taira.includes('symbol: "XOR"') ||
    !taira.includes('decimals: 9')) fail('canonical Taira native profile drifted without readiness review');
if (!nexus.includes('enabledByDefault: false')) fail('Nexus registry default is not provably disabled');

const appMarkers = [...project.matchAll(/INFOPLIST_FILE = fearless\/Info[.]plist;/g)];
const appBlocks = appMarkers.map((marker) => {
  const start = project.lastIndexOf('buildSettings = {', marker.index);
  const end = project.indexOf('\n\t\t\t};', marker.index);
  if (start < 0 || end < 0) fail('Fearless app build-settings boundary is malformed');
  return project.slice(start, end);
});
if (appBlocks.length !== 3 || appBlocks.some((block) => !block.includes('IPHONEOS_DEPLOYMENT_TARGET = 14.1;'))) {
  fail('Fearless app deployment target must remain iOS 14.1 while the SDK is blocked');
}
NODE

require_fixed "$PODFILE" \
  "config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.1'" \
  "CocoaPods iOS 14.1 deployment target"

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
  'iOS `14.1`' \
  'iOS `15.0`' \
  'public default arguments' \
  'None matches the corresponding published release slice' \
  '9756355bec7ca04a9e95025a0f24296a02118a5bf5989cc9c2cec0612bf76201' \
  'c072426bffe62e12fc6b94a0c37ecf4eb2a805965964ce999e5183bddc9a1ce7' \
  '6cc8aa66faa4b067c44831deaf225d8637ffd6daba05b11857b69a06a6b4279b' \
  'unpublished correction' \
  'fc56984b-2be7-431d-840e-21514d1883f0' \
  '6TEAJqbb8oEPmLncoNiMRbLEK6tw' \
  '7efcc118eb50e3369d004d092f9b9d0b4d31ac52' \
  'workspace-root live gate remains deployment authority' \
  'Swift `String`' \
  'Nexus wallet-smoke metadata boundary' \
  '"evidence_role": "wallet-smoke"' \
  '"route_governance_action_hash": "sha256:<64 lowercase nonzero hex characters>"' \
  '"wallet_platform": "ios"' \
  '"wallet_commit": "<40 lowercase nonzero git hex characters>"' \
  'Missing, extra, case-shifted, control-character, non-ASCII, malformed, and' \
  '`name#domain` aliases are not accepted' \
  'all six' \
  '`iroha.transactions.submit_and_wait`' \
  '`entrypoint_hash`' \
  '`spec.scale` of 9' \
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
  'iOS 14.1 versus SDK iOS 15 support decision' \
  'canonical compact transaction-hash parity' \
  'authoritative protocol chain ID' \
  'zeroizable secret-lifecycle boundary' \
  'exact local/top-level/transaction/receipt/final MCP hash equality' \
  'funded Taira and Nexus broadcast evidence' \
  'local unpublished upstream correction is diagnostic only'; do
  require_fixed "$RELEASE_CHECKLIST" "$marker" "release checklist Iroha gate '$marker'"
done

echo "[iroha-send-readiness][ios] 14.1/15, source/binary, parity, protocol, key-lifecycle, receipt, live-evidence, and fail-closed invariants passed."
