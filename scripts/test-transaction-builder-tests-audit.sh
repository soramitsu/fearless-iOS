#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit-transaction-builder-tests.sh"

fail() {
  echo "[ios-transaction-builder-audit-test][error] $*" >&2
  exit 1
}

write_file() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

write_valid_fixture() {
  local root="$1"

  write_file "$root/fearlessTests/BitcoinTransactionBuilderTests.swift" \
    "final class BitcoinTransactionBuilderTests {" \
    "  func testBuildsAndSignsMainnetP2wpkhTransactionMatchingWebVector() {}" \
    "  func testRejectsUnsafeUtxosOutputsFeesAndChangeHandlingBeforeSigning() {}" \
    "  func testRejectsUtxosThatDoNotMatchDerivedBip84KeyOrWitnessScript() {}" \
    "  func testRejectsEmptyMnemonicBeforeSigning() {}" \
    "}"

  write_file "$root/fearlessTests/SolanaTransferTransactionBuilderTests.swift" \
    "final class SolanaTransferTransactionBuilderTests {" \
    "  func testBuildsCanonicalLegacySystemTransferTransactionEnvelope() {}" \
    "  func testRejectsMalformedTransferParameters() {}" \
    "  func testBuildsCanonicalSPLTokenTransferCheckedTransactionEnvelope() {}" \
    "  func testBuildsToken2022TransferCheckedWithExtensionExtraAccountsInInstructionOrder() {}" \
    "  func testBuildsTokenSendWithIdempotentAssociatedTokenAccountCreateThenTransferChecked() {}" \
    "}"

  write_file "$root/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift" \
    "protocol IrohaTransferSigning {}" \
    "struct IrohaTransferSigningRequest {}" \
    "struct IrohaSignedTransfer {}"

  write_file "$root/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift" \
    "final class SendDependencyContainerUniversalWalletRoutingTests {" \
    "  func testIrohaTransferServiceBuildsSignerRequestAndSubmitsNorito() {}" \
    "  func testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation() {}" \
    "  func testIrohaTransferServiceRejectsMnemonicMismatchBeforeSignerOrToriiCalls() {}" \
    "  func testPrepareDependenciesFailsClosedForTonCompatibilityTransferBeforeSubstrateRouting() {}" \
    "}"

  write_file "$root/fearless/Modules/Send/SendDependencyContainer.swift" \
    "if chainAsset.chain.isTonCompatibilityChain {" \
    "  throw ConvenienceError(error: \"TON transfer not yet supported.\")" \
    "}"
}

run_audit() {
  local root="$1"
  IOS_TX_BUILDER_AUDIT_ROOT="$root" bash "$AUDIT_SCRIPT"
}

expect_success() {
  local root="$1"
  if ! run_audit "$root" >/dev/null; then
    fail "valid fixture unexpectedly failed"
  fi
}

expect_failure() {
  local name="$1"
  local root="$2"
  local expected="$3"
  local output

  set +e
  output="$(run_audit "$root" 2>&1)"
  local status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "$output" >&2
    fail "$name unexpectedly passed"
  fi

  if [[ "$output" != *"$expected"* ]]; then
    echo "$output" >&2
    fail "$name did not report expected text: $expected"
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

valid="$tmp_dir/valid"
write_valid_fixture "$valid"
expect_success "$valid"

missing_bitcoin="$tmp_dir/missing-bitcoin"
write_valid_fixture "$missing_bitcoin"
perl -0pi -e 's/testRejectsUnsafeUtxosOutputsFeesAndChangeHandlingBeforeSigning/testRejectsSomeBitcoinInput/' "$missing_bitcoin/fearlessTests/BitcoinTransactionBuilderTests.swift"
expect_failure "missing Bitcoin adversarial test" "$missing_bitcoin" "Bitcoin unsafe UTXO/output/fee adversarial test"

missing_solana="$tmp_dir/missing-solana"
write_valid_fixture "$missing_solana"
perl -0pi -e 's/testBuildsToken2022TransferCheckedWithExtensionExtraAccountsInInstructionOrder/testBuildsToken2022Transfer/' "$missing_solana/fearlessTests/SolanaTransferTransactionBuilderTests.swift"
expect_failure "missing Solana Token-2022 test" "$missing_solana" "Solana Token-2022 extra-account ordering test"

missing_iroha="$tmp_dir/missing-iroha"
write_valid_fixture "$missing_iroha"
perl -0pi -e 's/testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation/testIrohaTransferServiceDefaultSigner/' "$missing_iroha/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing Iroha fail-closed test" "$missing_iroha" "Iroha default signer fail-closed test"

missing_ton="$tmp_dir/missing-ton"
write_valid_fixture "$missing_ton"
perl -0pi -e 's/isTonCompatibilityChain/isSomeOtherChain/' "$missing_ton/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "missing TON fail-closed guard" "$missing_ton" "TON compatibility transfer guard"

echo "[ios-transaction-builder-audit-test] all tests passed"
