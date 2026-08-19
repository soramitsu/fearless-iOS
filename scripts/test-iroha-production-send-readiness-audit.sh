#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))"
AUDIT="$ROOT_DIR/scripts/audit-iroha-production-send-readiness.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fearless-ios-iroha-send.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
negative_count=0

fail() {
  echo "[iroha-send-readiness-test][ios][error] $*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

new_fixture() {
  local name="$1"
  local fixture="$TMP_DIR/$name"
  mkdir -p \
    "$fixture/config" "$fixture/docs" "$fixture/fearless.xcodeproj" \
    "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens" \
    "$fixture/fearless/Modules/Send" \
    "$fixture/fearless/Common/Model" \
    "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle"
  cp "$ROOT_DIR/config/iroha-production-send-readiness.json" "$fixture/config/"
  cp "$ROOT_DIR/docs/iroha-production-send-readiness.md" "$fixture/docs/"
  cp "$ROOT_DIR/docs/universal-wallet-v2.md" "$fixture/docs/"
  cp "$ROOT_DIR/docs/release-checklist.md" "$fixture/docs/"
  cp "$ROOT_DIR/Podfile" "$fixture/"
  cp "$ROOT_DIR/fearless.xcodeproj/project.pbxproj" "$fixture/fearless.xcodeproj/"
  cp "$ROOT_DIR/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift" \
    "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/"
  cp "$ROOT_DIR/fearless/Modules/Send/SendDependencyContainer.swift" "$fixture/fearless/Modules/Send/"
  cp "$ROOT_DIR/fearless/Common/Model/UniversalWalletRegistry.swift" "$fixture/fearless/Common/Model/"
  cp "$ROOT_DIR/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift" \
    "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/"
  (
    cd "$fixture"
    git init -q
    git add .
  )
  printf '%s' "$fixture"
}

run_audit() {
  local fixture="$1"
  local audit="${2:-$AUDIT}"
  IROHA_SEND_AUDIT_ROOT="$fixture" "$audit"
}

expect_failure() {
  local label="$1"
  local fixture="$2"
  local expected="$3"
  local audit="${4:-$AUDIT}"
  local output status
  set +e
  output="$(run_audit "$fixture" "$audit" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    fail "$label unexpectedly passed"
  fi
  [[ "$output" == *"$expected"* ]] || {
    printf '%s\n' "$output" >&2
    fail "$label did not report expected marker: $expected"
  }
  negative_count=$((negative_count + 1))
}

mutate_manifest() {
  local fixture="$1"
  local field_path="$2"
  local json_value="$3"
  node - "$fixture/config/iroha-production-send-readiness.json" "$field_path" "$json_value" <<'NODE'
const fs = require('node:fs');
const file = process.argv[2];
const path = process.argv[3].split('.');
const value = JSON.parse(process.argv[4]);
const manifest = JSON.parse(fs.readFileSync(file, 'utf8'));
let target = manifest;
for (const key of path.slice(0, -1)) {
  if (!target[key] || typeof target[key] !== 'object') target[key] = {};
  target = target[key];
}
target[path.at(-1)] = value;
fs.writeFileSync(file, `${JSON.stringify(manifest, null, 2)}\n`);
NODE
}

repinned_audit() {
  local fixture="$1"
  local digest audit_copy
  digest="$(sha256_file "$fixture/config/iroha-production-send-readiness.json")"
  audit_copy="$fixture/audit-repinned.sh"
  cp "$AUDIT" "$audit_copy"
  perl -0pi -e \
    's/EXPECTED_MANIFEST_SHA256="[0-9a-f]{64}"/EXPECTED_MANIFEST_SHA256="'"$digest"'"/' \
    "$audit_copy"
  chmod +x "$audit_copy"
  printf '%s' "$audit_copy"
}

expect_manifest_failure() {
  local label="$1"
  local field_path="$2"
  local json_value="$3"
  local expected="$4"
  local fixture audit_copy
  fixture="$(new_fixture "manifest-$label")"
  mutate_manifest "$fixture" "$field_path" "$json_value"
  audit_copy="$(repinned_audit "$fixture")"
  expect_failure "manifest $label" "$fixture" "$expected" "$audit_copy"
}

valid="$(new_fixture valid)"
run_audit "$valid" >/dev/null

fixture="$(new_fixture manifest-digest-tamper)"
sed -i.bak 's/"releaseEnabled": false/"releaseEnabled": true/' "$fixture/config/iroha-production-send-readiness.json"
rm -f "$fixture/config/iroha-production-send-readiness.json.bak"
expect_failure "manifest digest tamper" "$fixture" "manifest digest mismatch"

# Repin only the temporary fixture audit so every semantic assertion is tested,
# independently of the production manifest's outer digest lock.
expect_manifest_failure "extra-key" "unexpected" 'true' "top-level manifest keys drifted"
expect_manifest_failure "schema" "schemaVersion" '3' "schemaVersion must be 2"
expect_manifest_failure "platform" "platform" '"android"' "platform must be ios"
expect_manifest_failure "date" "assessedAt" '"2026-07-10"' "assessment date drifted"
expect_manifest_failure "status" "status" '"ready"' "status must remain blocked"
expect_manifest_failure "release-enabled" "releaseEnabled" 'true' "releaseEnabled must remain false"
expect_manifest_failure "nexus-enabled" "nexusEnabledByDefault" 'true' "Nexus must remain disabled by default"
expect_manifest_failure "tag" "upstream.tag" '"v0"' "unexpected upstream tag"
expect_manifest_failure "commit" "upstream.commit" '"0000000000000000000000000000000000000000"' "unexpected upstream commit"
expect_manifest_failure "artifact-digest" "artifact.sha256" '"0000000000000000000000000000000000000000000000000000000000000000"' "unexpected Apple artifact digest"
expect_manifest_failure "artifact-size" "artifact.bytes" '1' "unexpected Apple artifact size"
expect_manifest_failure "entry-count" "artifact.entryCount" '19' "archive entry count drifted"
expect_manifest_failure "expanded-size" "artifact.expandedBytes" '1396110348' "archive expanded size drifted"
expect_manifest_failure "max-entry" "artifact.maxEntryBytes" '704780503' "archive maximum entry size drifted"
expect_manifest_failure "app-minimum" "integrationAssessment.appMinimumIOS" '"14.1"' "app minimum iOS evidence drifted"
expect_manifest_failure "sdk-minimum" "integrationAssessment.sdkMinimumIOS" '"14.1"' "SDK minimum iOS evidence drifted"
expect_manifest_failure "os-compatible" "integrationAssessment.minimumOSCompatible" 'false' "minimum OS compatibility evidence drifted"
expect_manifest_failure "os-change-approved" "integrationAssessment.productMinimumOSChangeApproved" 'false' "approved product minimum OS change evidence drifted"
expect_manifest_failure "linkage-approved" "integrationAssessment.sdkLinkageApproved" 'true' "SDK linkage must remain unapproved"
expect_manifest_failure "package-delivery" "integrationAssessment.taggedPackageDelivery" '"remote-binary-target"' "tagged package delivery evidence drifted"
expect_manifest_failure "compile-status" "integrationAssessment.taggedCompileStatus" '"passed"' "tagged compile failure must remain explicit"
expect_manifest_failure "loader-hash" "integrationAssessment.taggedSwiftLoaderExpectedSliceSha256.ios-arm64" '"0000000000000000000000000000000000000000000000000000000000000000"' "tagged Swift loader hashes drifted"
expect_manifest_failure "slice-match" "integrationAssessment.publishedSlicesMatchTaggedLoader" 'true' "source/artifact slice mismatch must remain explicit"
expect_manifest_failure "provenance" "integrationAssessment.buildProvenanceBundled" 'true' "missing build provenance evidence drifted"
expect_manifest_failure "canonical-hash" "transactionParity.currentMainCompactEntrypointHash" '"0000000000000000000000000000000000000000000000000000000000000000"' "compact entrypoint hash drifted"
expect_manifest_failure "fixed-hash" "transactionParity.fixedU64EntrypointHash" '"0000000000000000000000000000000000000000000000000000000000000000"' "fixed-u64 diagnostic hash drifted"
expect_manifest_failure "stale-hash" "transactionParity.taggedSwiftRawFixtureHash" '"0000000000000000000000000000000000000000000000000000000000000000"' "tagged Swift parity hash drifted"
expect_manifest_failure "tag-parity" "transactionParity.officialTagParityStatus" '"canonical"' "official tag parity blocker drifted"
expect_manifest_failure "local-correction" "transactionParity.localCompactCorrectionStatus" '"published-reviewed"' "local correction must not be release evidence"
expect_manifest_failure "live-parity" "transactionParity.liveReceiptParity" '"passed"' "live receipt parity must remain blocked"
expect_manifest_failure "protocol-chain" "networkReadiness.protocolChainIdMapping" '"same-as-route"' "protocol chain ID mapping must remain blocked"
expect_manifest_failure "live-asset" "networkReadiness.liveTairaNativeXorDefinitionId" '"00000000000000000000000000000000000000000000"' "live Taira XOR definition drifted"
expect_manifest_failure "asset-scale" "networkReadiness.liveTairaNativeXorScale" '18' "live Taira XOR scale drifted"
expect_manifest_failure "asset-alias" "networkReadiness.liveTairaNativeXorAlias" '"xor#wrong"' "live Taira canonical alias drifted"
expect_manifest_failure "alternate-asset" "networkReadiness.liveTairaAlternateXorDefinitionId" '"00000000000000000000000000000000000000000000"' "live Taira alternate XOR definition drifted"
expect_manifest_failure "fee-policy" "networkReadiness.authoritativeFeePolicy" '"zero"' "authoritative fee policy must remain blocked"
expect_manifest_failure "node-version" "networkReadiness.liveTairaNodeVersion" '"2.0.0-rc.2.1"' "live Taira node version drifted"
expect_manifest_failure "node-compatibility" "networkReadiness.sdkToDeployedNodeCompatibility" '"proven"' "SDK/deployed-node compatibility must remain blocked"
expect_manifest_failure "secret-representation" "securityBoundary.secretRequestRepresentation" '"secure-bytes"' "secret representation risk drifted"
expect_manifest_failure "secret-zeroization" "securityBoundary.secretCopiesReliablyZeroizable" 'true' "secret zeroization gap must remain explicit"
expect_manifest_failure "submission-policy" "securityBoundary.submissionHashPolicy" '"exact-match"' "submission hash-policy gap drifted"
expect_manifest_failure "receipt-equality" "securityBoundary.receiptHashEqualityRequired" 'false' "receipt hash equality must be required"
expect_manifest_failure "live-funded" "liveEvidence.fundedTairaBroadcast" '"passed"' "live evidence fundedTairaBroadcast must remain unavailable"
expect_manifest_failure "blocker" "blocker.code" '"ready"' "unexpected blocker code"
expect_manifest_failure "exit-criteria" "exitCriteria" '[]' "exactly ten exit criteria are required"

fixture="$(new_fixture invalid-json)"
printf '{invalid\n' > "$fixture/config/iroha-production-send-readiness.json"
audit_copy="$(repinned_audit "$fixture")"
expect_failure "invalid JSON" "$fixture" "invalid readiness JSON" "$audit_copy"

fixture="$(new_fixture service-bypass)"
sed -i.bak 's/signer: IrohaTransferSigning = UnavailableIrohaTransferSigner()/signer: IrohaTransferSigning = ReviewedSigner()/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "service bypass" "$fixture" "fail-closed service default"

fixture="$(new_fixture container-injection)"
sed -i.bak 's/return IrohaTransferService(wallet: wallet, chain: chainAsset.chain)/return IrohaTransferService(wallet: wallet, chain: chainAsset.chain, signer: ReviewedSigner())/' \
  "$fixture/fearless/Modules/Send/SendDependencyContainer.swift"
rm -f "$fixture/fearless/Modules/Send/SendDependencyContainer.swift.bak"
expect_failure "container injection" "$fixture" "send container fail-closed construction"

fixture="$(new_fixture early-guard-removed)"
sed -i.bak \
  's/throw UniversalWalletSendRoutingError.irohaProductionSendDisabled/throw ChainAccountFetchingError.accountNotExists/' \
  "$fixture/fearless/Modules/Send/SendDependencyContainer.swift"
rm -f "$fixture/fearless/Modules/Send/SendDependencyContainer.swift.bak"
expect_failure "early Iroha guard removed" "$fixture" "early Iroha production-disable guard"

fixture="$(new_fixture early-guard-after-account-lookup)"
perl -0pi -e \
  's/(        if isUniversalWalletIroha\(chainAsset[.]chain\) \{\n            throw UniversalWalletSendRoutingError[.]irohaProductionSendDisabled\n        \}\n\n)(        guard let accountResponse = wallet[.]fetch\(for: chainAsset[.]chain[.]accountRequest\(\)\) else \{\n            throw ChainAccountFetchingError[.]accountNotExists\n        \}\n)/$2\n$1/' \
  "$fixture/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "late Iroha guard" "$fixture" "Iroha production-disable guard must precede account lookup"

fixture="$(new_fixture early-guard-test-removed)"
sed -i.bak \
  's/testProductionSendDependenciesRejectIrohaBeforeServiceConstruction/testProductionSendDependenciesRejectIroha/' \
  "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
rm -f "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift.bak"
expect_failure "early Iroha guard test removed" "$fixture" "early production Iroha send-disable test"

fixture="$(new_fixture duplicate-container-bypass)"
perl -0pi -e \
  's/        if isUniversalWalletIroha\(chainAsset[.]chain\) \{\n/        if isUniversalWalletIroha(chainAsset.chain) {\n            if Bool.random() { return IrohaTransferService(wallet: wallet, chain: chainAsset.chain, signer: ReviewedSigner()) }\n/' \
  "$fixture/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "duplicate container bypass" "$fixture" "exactly one audited fail-closed Iroha service construction"

fixture="$(new_fixture signer-no-longer-fails)"
sed -i.bak 's/Iroha transfer signing codec is unavailable/temporary fallback/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "signer no longer fails explicitly" "$fixture" "unavailable signer exception"

fixture="$(new_fixture secret-obscured)"
sed -i.bak 's/let mnemonicOrSeed: String/let secret: String/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "secret risk obscured" "$fixture" "immutable Swift secret risk marker"

fixture="$(new_fixture protocol-chain-assumed)"
sed -i.bak 's/chainId: network.chainId/chainId: "taira"/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "protocol chain assumed" "$fixture" "route-label signing-chain ambiguity marker"

fixture="$(new_fixture fee-assumed-zero-safe)"
sed -i.bak 's/return .zero/return BigUInt(1)/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "fee behavior changed" "$fixture" "unresolved zero-fee marker"

fixture="$(new_fixture receipt-fallback-removed)"
sed -i.bak 's/?? receipt.payload.signedTransactionHash/?? receipt.payload.txHash/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "receipt fallback changed" "$fixture" "receipt signed-transaction hash fallback"

fixture="$(new_fixture finality-silently-added)"
perl -0pi -e \
  's/(        return signedTransfer[.]transactionHashHex)/        _ = transactionStatus(hash: "unchecked")\n\n$1/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
expect_failure "unreviewed finality change" "$fixture" "submission finality behavior changed without readiness review"

fixture="$(new_fixture nexus-enabled)"
node - "$fixture/fearless/Common/Model/UniversalWalletRegistry.swift" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
const text = fs.readFileSync(path, 'utf8');
const start = text.indexOf('static let nexus = IrohaNetwork(');
const end = text.indexOf('\n    )', start);
fs.writeFileSync(path, text.slice(0, start) + text.slice(start, end).replace('enabledByDefault: false', 'enabledByDefault: true') + text.slice(end));
NODE
expect_failure "Nexus enabled" "$fixture" "Nexus registry default"

fixture="$(new_fixture taira-route-drift)"
sed -i.bak 's/chainId: "iroha3-taira"/chainId: "taira"/' "$fixture/fearless/Common/Model/UniversalWalletRegistry.swift"
rm -f "$fixture/fearless/Common/Model/UniversalWalletRegistry.swift.bak"
expect_failure "Taira route drift" "$fixture" "Taira route label drifted"

fixture="$(new_fixture app-minimum-lowered)"
perl -0pi -e \
  's/(INFOPLIST_FILE = fearless\/Info[.]plist;\n[[:space:]]*IPHONEOS_DEPLOYMENT_TARGET = )15[.]0;/${1}14.1;/' \
  "$fixture/fearless.xcodeproj/project.pbxproj"
expect_failure "app minimum lowered" "$fixture" "deployment target must remain exactly iOS 15.0"

fixture="$(new_fixture pod-minimum-lowered)"
sed -i.bak "s/IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'/IPHONEOS_DEPLOYMENT_TARGET'] = '14.1'/" "$fixture/Podfile"
rm -f "$fixture/Podfile.bak"
expect_failure "Pod minimum lowered" "$fixture" "CocoaPods iOS 15.0 deployment target"

fixture="$(new_fixture package-added)"
printf '\nrepositoryURL = "https://github.com/hyperledger/iroha";\nproductName = IrohaSwift;\n' >> "$fixture/fearless.xcodeproj/project.pbxproj"
expect_failure "unreviewed Xcode Swift package" "$fixture" "dependency graph before review"

fixture="$(new_fixture pod-added)"
printf '\npod "IrohaSwift"\n' >> "$fixture/Podfile"
expect_failure "unreviewed CocoaPod" "$fixture" "CocoaPods before review"

fixture="$(new_fixture package-manifest-added)"
printf '// swift-tools-version: 5.9\n// IrohaSwift https://github.com/hyperledger/iroha\n' > "$fixture/Package.swift"
expect_failure "unreviewed package manifest" "$fixture" "dependency manifest appeared before review"

fixture="$(new_fixture product-import-added)"
printf 'import IrohaSwift\n' > "$fixture/fearless/Injected.swift"
expect_failure "unreviewed product import" "$fixture" "imported into product source before review"

fixture="$(new_fixture local-xcframework)"
mkdir -p "$fixture/vendor/NoritoBridge.xcframework"
expect_failure "local untracked XCFramework" "$fixture" "SDK/native binary material"

fixture="$(new_fixture tracked-xcframework)"
mkdir -p "$fixture/vendor"
printf 'binary\n' > "$fixture/vendor/NoritoBridge.xcframework.zip"
git -C "$fixture" add .
expect_failure "tracked XCFramework" "$fixture" "SDK/native binary material"

fixture="$(new_fixture second-signer-file)"
printf 'struct HiddenSigner: IrohaTransferSigning {}\n' > "$fixture/fearless/HiddenSigner.swift"
expect_failure "second signer file" "$fixture" "signer implementation appeared outside"

fixture="$(new_fixture second-service-call)"
printf 'let hidden = IrohaTransferService(wallet: wallet, chain: chain)\n' > "$fixture/fearless/HiddenService.swift"
expect_failure "second service call" "$fixture" "construction appeared outside"

fixture="$(new_fixture fail-closed-test-removed)"
sed -i.bak 's/testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation/testIrohaTransferServiceDefaultSigner/' \
  "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
rm -f "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift.bak"
expect_failure "fail-closed test removed" "$fixture" "default signer fail-closed test"

fixture="$(new_fixture mismatch-test-removed)"
sed -i.bak 's/testIrohaTransferServiceRejectsMnemonicMismatchBeforeSignerOrToriiCalls/testIrohaMismatch/' \
  "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
rm -f "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift.bak"
expect_failure "mismatch test removed" "$fixture" "mnemonic/key mismatch adversarial test"

fixture="$(new_fixture metadata-field-removed)"
sed -i.bak 's/let metadata: IrohaTransactionMetadata/let metadataRemoved: IrohaTransactionMetadata/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "metadata field removed" "$fixture" "Iroha signing request metadata seam"

fixture="$(new_fixture ordinary-metadata-enabled)"
sed -i.bak \
  's/submitValidated(transfer: transfer, metadata: .none)/submitValidated(transfer: transfer, metadata: unsafeMetadata)/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "ordinary metadata enabled" "$fixture" "ordinary Iroha transfers must omit transaction metadata"

fixture="$(new_fixture evidence-hook-removed)"
sed -i.bak 's/func submitNexusWalletSmokeEvidence(/func submitUnreviewedEvidence(/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "evidence hook removed" "$fixture" "operator-only Nexus wallet-smoke evidence hook"

fixture="$(new_fixture metadata-role-drift)"
sed -i.bak \
  's/untrustedMetadata\[evidenceRoleKey\] == "wallet-smoke"/untrustedMetadata[evidenceRoleKey] == "wallet_smoke"/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "metadata role drift" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture metadata-platform-drift)"
sed -i.bak \
  's/untrustedMetadata\[walletPlatformKey\] == "ios"/untrustedMetadata[walletPlatformKey] == "iOS"/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "metadata platform drift" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture metadata-key-drift)"
sed -i.bak \
  's/static let routeGovernanceActionHashKey = "route_governance_action_hash"/static let routeGovernanceActionHashKey = "route_action_hash"/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "metadata key drift" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture metadata-field-set-bypass)"
sed -i.bak 's/untrustedMetadata.count == expectedKeys.count/true/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "metadata field-set bypass" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture metadata-constructor-exposed)"
sed -i.bak 's/private init(snapshot: \[String: String\])/init(snapshot: [String: String])/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "metadata constructor exposed" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture zero-route-hash-accepted)"
sed -i.bak \
  's/routeHash != routeHashPrefix + String(repeating: "0", count: 64)/true/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "zero route hash accepted" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture zero-wallet-commit-accepted)"
sed -i.bak \
  's/walletCommit != String(repeating: "0", count: 40)/true/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "zero wallet commit accepted" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture evidence-network-bypass)"
sed -i.bak 's/context.signingRequest.network == "nexus"/true/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "evidence network bypass" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture evidence-original-chain-bypass)"
sed -i.bak \
  's/chain.chainId == UniversalWalletRegistry.nexus.chainId/true/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "evidence original chain bypass" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture evidence-endpoint-bypass)"
sed -i.bak \
  's/context.toriiBaseURL == UniversalWalletRegistry.nexus.toriiBaseURL?.absoluteString/true/' \
  "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
rm -f "$fixture/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift.bak"
expect_failure "evidence endpoint bypass" "$fixture" "wallet-smoke metadata invariant"

fixture="$(new_fixture metadata-negative-test-removed)"
sed -i.bak \
  's/testIrohaNexusWalletSmokeEvidenceRejectsMalformedMetadataBeforeSignerOrTorii/testIrohaMetadataNegative/' \
  "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
rm -f "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift.bak"
expect_failure "metadata negative test removed" "$fixture" "wallet-smoke adversarial test"

fixture="$(new_fixture metadata-alias-test-removed)"
sed -i.bak \
  's/testIrohaWalletSmokeMetadataSnapshotDoesNotAliasInputOrReturnedValues/testIrohaMetadataAlias/' \
  "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
rm -f "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift.bak"
expect_failure "metadata alias test removed" "$fixture" "wallet-smoke adversarial test"

fixture="$(new_fixture metadata-fail-closed-test-removed)"
sed -i.bak \
  's/testIrohaWalletSmokeEvidenceRemainsFailClosedWithUnavailableSigner/testIrohaMetadataFailClosed/' \
  "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
rm -f "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift.bak"
expect_failure "metadata fail-closed test removed" "$fixture" "wallet-smoke adversarial test"

fixture="$(new_fixture nonmaterializing-endpoint-fixture)"
sed -i.bak \
  's/ChainModel.BlockExplorer(type: "sora", url: url)/ChainModel.BlockExplorer(type: "iroha", url: url)/' \
  "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
rm -f "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift.bak"
expect_failure \
  "nonmaterializing endpoint fixture" \
  "$fixture" \
  "materialized Nexus endpoint adversarial fixture"

for hostile_url in \
  'https://nexus-proxy.example' \
  'http://minamoto.sora.org' \
  'https://minamoto.sora.org.attacker.invalid' \
  'https://minamoto.sora.org@attacker.invalid' \
  'https://minamoto.sora.org:444' \
  'https://minamoto.sora.org/v1/mcp' \
  'https://minamoto.sora.org?redirect=https://attacker.invalid' \
  'https://minamoto.sora.org#@attacker.invalid' \
  'https://minamoto.sora.org/'; do
  fixture="$(new_fixture "endpoint-case-$(printf '%s' "$hostile_url" | shasum -a 256 | cut -c1-12)")"
  HOSTILE_URL="$hostile_url" node - \
    "$fixture/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift" <<'NODE'
const fs = require('node:fs');
const file = process.argv[2];
const hostileURL = process.env.HOSTILE_URL;
const source = fs.readFileSync(file, 'utf8');
const quotedURL = `"${hostileURL}"`;
if (!source.includes(quotedURL)) {
  throw new Error(`missing hostile URL fixture: ${hostileURL}`);
}
fs.writeFileSync(file, source.replace(quotedURL, '"https://removed.invalid"'));
NODE
  expect_failure \
    "hostile endpoint fixture removed: $hostile_url" \
    "$fixture" \
    "materialized Nexus endpoint adversarial fixture"
done

fixture="$(new_fixture evidence-redacted)"
sed -i.bak 's/1396110349/unknown/g' "$fixture/docs/iroha-production-send-readiness.md"
rm -f "$fixture/docs/iroha-production-send-readiness.md.bak"
expect_failure "release evidence redacted" "$fixture" "readiness evidence marker"

fixture="$(new_fixture local-fix-promoted)"
sed -i.bak 's/unpublished correction/published correction/g' "$fixture/docs/iroha-production-send-readiness.md"
rm -f "$fixture/docs/iroha-production-send-readiness.md.bak"
expect_failure "local fix promoted" "$fixture" "unpublished correction"

fixture="$(new_fixture capability-claim-regressed)"
sed -i.bak 's/is capability metadata, not a production-send/is production-send/' "$fixture/docs/universal-wallet-v2.md"
rm -f "$fixture/docs/universal-wallet-v2.md.bak"
expect_failure "capability claim regressed" "$fixture" "Universal Wallet non-enablement statement"

fixture="$(new_fixture checklist-gate-removed)"
sed -i.bak 's/exact local\/Torii receipt-hash equality/local receipt hash/' "$fixture/docs/release-checklist.md"
rm -f "$fixture/docs/release-checklist.md.bak"
expect_failure "release checklist gate removed" "$fixture" "release checklist Iroha gate"

fixture="$(new_fixture manifest-symlink)"
rm "$fixture/config/iroha-production-send-readiness.json"
ln -s ../docs/iroha-production-send-readiness.md "$fixture/config/iroha-production-send-readiness.json"
expect_failure "manifest symlink" "$fixture" "missing or is a symlink"

fixture="$(new_fixture doc-symlink)"
rm "$fixture/docs/iroha-production-send-readiness.md"
ln -s universal-wallet-v2.md "$fixture/docs/iroha-production-send-readiness.md"
expect_failure "document symlink" "$fixture" "missing or is a symlink"

echo "[iroha-send-readiness-test][ios] $negative_count negative/adversarial fixtures passed."
