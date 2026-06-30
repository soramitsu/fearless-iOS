#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${IOS_TX_BUILDER_AUDIT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))}"

failures=()

record_failure() {
  failures+=("$1")
  echo "[ios-transaction-builder-audit][warn] $1" >&2
}

require_file() {
  local file="$1"
  local description="$2"
  [[ -f "$file" ]] || record_failure "$description missing: $file"
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if [[ ! -f "$file" ]]; then
    return
  fi
  if ! grep -Eq -- "$pattern" "$file"; then
    record_failure "$description missing in $file"
  fi
}

bitcoin_tests="$ROOT_DIR/fearlessTests/BitcoinTransactionBuilderTests.swift"
solana_tests="$ROOT_DIR/fearlessTests/SolanaTransferTransactionBuilderTests.swift"
routing_tests="$ROOT_DIR/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
transfer_service="$ROOT_DIR/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
send_container="$ROOT_DIR/fearless/Modules/Send/SendDependencyContainer.swift"

require_file "$bitcoin_tests" "Bitcoin transaction builder tests"
require_pattern "$bitcoin_tests" 'final class BitcoinTransactionBuilderTests' "Bitcoin transaction builder test class"
require_pattern "$bitcoin_tests" 'testBuildsAndSignsMainnetP2wpkhTransactionMatchingWebVector' "Bitcoin canonical P2WPKH vector test"
require_pattern "$bitcoin_tests" 'testRejectsUnsafeUtxosOutputsFeesAndChangeHandlingBeforeSigning' "Bitcoin unsafe UTXO/output/fee adversarial test"
require_pattern "$bitcoin_tests" 'testRejectsUtxosThatDoNotMatchDerivedBip84KeyOrWitnessScript' "Bitcoin BIP84 witness mismatch adversarial test"
require_pattern "$bitcoin_tests" 'testRejectsEmptyMnemonicBeforeSigning' "Bitcoin empty mnemonic adversarial test"

require_file "$solana_tests" "Solana transfer transaction builder tests"
require_pattern "$solana_tests" 'final class SolanaTransferTransactionBuilderTests' "Solana transaction builder test class"
require_pattern "$solana_tests" 'testBuildsCanonicalLegacySystemTransferTransactionEnvelope' "Solana native transfer envelope test"
require_pattern "$solana_tests" 'testRejectsMalformedTransferParameters' "Solana malformed native transfer adversarial test"
require_pattern "$solana_tests" 'testBuildsCanonicalSPLTokenTransferCheckedTransactionEnvelope' "Solana SPL Token transfer-checked test"
require_pattern "$solana_tests" 'testBuildsToken2022TransferCheckedWithExtensionExtraAccountsInInstructionOrder' "Solana Token-2022 extra-account ordering test"
require_pattern "$solana_tests" 'testBuildsTokenSendWithIdempotentAssociatedTokenAccountCreateThenTransferChecked' "Solana ATA create plus transfer builder test"

require_file "$transfer_service" "Iroha transfer service signer seam"
require_pattern "$transfer_service" 'protocol IrohaTransferSigning' "Iroha transfer signer seam"
require_pattern "$transfer_service" 'struct IrohaTransferSigningRequest' "Iroha transfer signing request contract"
require_pattern "$transfer_service" 'struct IrohaSignedTransfer' "Iroha signed transfer contract"

require_file "$routing_tests" "Universal wallet send routing tests"
require_pattern "$routing_tests" 'testIrohaTransferServiceBuildsSignerRequestAndSubmitsNorito' "Iroha signer request and Torii submission test"
require_pattern "$routing_tests" 'testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation' "Iroha default signer fail-closed test"
require_pattern "$routing_tests" 'testIrohaTransferServiceRejectsMnemonicMismatchBeforeSignerOrToriiCalls' "Iroha mnemonic mismatch adversarial test"
require_pattern "$routing_tests" 'testPrepareDependenciesFailsClosedForTonCompatibilityTransferBeforeSubstrateRouting' "TON transfer fail-closed routing test"

require_file "$send_container" "Send dependency container"
require_pattern "$send_container" 'isTonCompatibilityChain' "TON compatibility transfer guard"
require_pattern "$send_container" 'TON transfer not yet supported\.' "TON transfer explicit fail-closed error"

if ((${#failures[@]} > 0)); then
  echo "[ios-transaction-builder-audit][error] iOS transaction-builder coverage audit failed:" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi

echo "[ios-transaction-builder-audit] iOS transaction-builder coverage audit passed."
