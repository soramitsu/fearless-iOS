import XCTest
@testable import fearless

final class BitcoinTransactionBuilderTests: XCTestCase {
    func testBuildsAndSignsMainnetP2wpkhTransactionMatchingWebVector() throws {
        let result = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
            mnemonic: Self.mnemonic,
            inputs: [
                BitcoinSpendableUtxo(
                    address: Self.mainnetAddress,
                    txid: Self.txid,
                    valueSats: 100_000,
                    vout: 1
                )
            ],
            outputs: [BitcoinPaymentOutput(address: Self.mainnetRecipient, valueSats: 50_000)],
            changeAddress: Self.mainnetAddress,
            feeRateSatPerVbyte: 2
        )

        XCTAssertEqual(result.feeSats, 282)
        XCTAssertEqual(result.changeSats, 49_718)
        XCTAssertEqual(result.inputTotalSats, 100_000)
        XCTAssertEqual(result.outputTotalSats, 50_000)
        XCTAssertEqual(result.vsize, 141)
        XCTAssertEqual(result.txid, Self.expectedTxid)
        XCTAssertEqual(result.txHex, Self.expectedTxHex)
    }

    func testSupportsExplicitFeeSpendWithNoChangeOutput() throws {
        let result = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
            mnemonic: Self.mnemonic,
            inputs: [
                BitcoinSpendableUtxo(
                    txid: String(repeating: "22", count: 32),
                    valueSats: 51_000,
                    vout: 0
                )
            ],
            outputs: [BitcoinPaymentOutput(address: Self.mainnetRecipient, valueSats: 50_000)],
            feeSats: 1_000
        )

        XCTAssertEqual(result.changeSats, 0)
        XCTAssertEqual(result.feeSats, 1_000)
        XCTAssertEqual(result.outputTotalSats, 50_000)
    }

    func testRejectsUnsafeUtxosOutputsFeesAndChangeHandlingBeforeSigning() {
        let baseInput = BitcoinSpendableUtxo(txid: Self.txid, valueSats: 100_000, vout: 0)
        let baseOutput = BitcoinPaymentOutput(address: Self.mainnetRecipient, valueSats: 50_000)

        assertTransactionError(.inputsRequired) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [],
                outputs: [baseOutput],
                feeSats: 1_000
            )
        }
        assertTransactionError(.invalidTxid) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [BitcoinSpendableUtxo(txid: "zz", valueSats: 100_000, vout: 0)],
                outputs: [baseOutput],
                feeSats: 1_000
            )
        }
        assertTransactionError(.duplicateUtxo) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [baseInput, baseInput],
                outputs: [baseOutput],
                feeSats: 1_000
            )
        }
        assertTransactionError(.satoshiOverflow) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [
                    BitcoinSpendableUtxo(txid: Self.txid, valueSats: BitcoinUtxoSelector.maxSatoshi, vout: 0),
                    BitcoinSpendableUtxo(txid: String(repeating: "22", count: 32), valueSats: 1, vout: 0)
                ],
                outputs: [baseOutput],
                feeSats: 1_000
            )
        }
        assertTransactionError(.invalidOutputAddress) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [baseInput],
                outputs: [BitcoinPaymentOutput(address: Self.testnetAddress, valueSats: 50_000)],
                feeSats: 1_000
            )
        }
        assertTransactionError(.satoshiOverflow) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [BitcoinSpendableUtxo(txid: Self.txid, valueSats: BitcoinUtxoSelector.maxSatoshi, vout: 0)],
                outputs: [
                    BitcoinPaymentOutput(address: Self.mainnetRecipient, valueSats: BitcoinUtxoSelector.maxSatoshi),
                    BitcoinPaymentOutput(address: Self.mainnetAddress, valueSats: BitcoinUtxoSelector.bitcoinP2wpkhDustSats)
                ],
                feeSats: 1_000
            )
        }
        assertTransactionError(.invalidOutputValue) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [baseInput],
                outputs: [
                    BitcoinPaymentOutput(
                        address: Self.mainnetRecipient,
                        valueSats: BitcoinUtxoSelector.bitcoinP2wpkhDustSats - 1
                    )
                ],
                feeSats: 1_000
            )
        }
        assertTransactionError(.invalidFee) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [baseInput],
                outputs: [baseOutput],
                feeSats: 0
            )
        }
        assertTransactionError(.invalidFeeRate) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [baseInput],
                outputs: [baseOutput],
                feeRateSatPerVbyte: 0
            )
        }
        assertTransactionError(.insufficientFunds) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [BitcoinSpendableUtxo(txid: Self.txid, valueSats: 50_500, vout: 0)],
                outputs: [baseOutput],
                feeSats: 1_000
            )
        }
        assertTransactionError(.changeAddressRequired) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [BitcoinSpendableUtxo(txid: Self.txid, valueSats: 52_000, vout: 0)],
                outputs: [baseOutput],
                feeSats: 1_000
            )
        }
        assertTransactionError(.changeBelowDust) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [BitcoinSpendableUtxo(txid: Self.txid, valueSats: 50_900, vout: 0)],
                outputs: [baseOutput],
                changeAddress: Self.mainnetAddress,
                feeSats: 800
            )
        }
    }

    func testRejectsUtxosThatDoNotMatchDerivedBip84KeyOrWitnessScript() {
        assertTransactionError(.utxoAddressMismatch) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [
                    BitcoinSpendableUtxo(
                        address: Self.mainnetRecipient,
                        txid: Self.txid,
                        valueSats: 51_000,
                        vout: 0
                    )
                ],
                outputs: [BitcoinPaymentOutput(address: Self.mainnetRecipient, valueSats: 50_000)],
                feeSats: 1_000
            )
        }

        assertTransactionError(.utxoScriptMismatch) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [
                    BitcoinSpendableUtxo(
                        scriptPubKey: "0014\(String(repeating: "00", count: 20))",
                        txid: Self.txid,
                        valueSats: 51_000,
                        vout: 0
                    )
                ],
                outputs: [BitcoinPaymentOutput(address: Self.mainnetRecipient, valueSats: 50_000)],
                feeSats: 1_000
            )
        }

        assertTransactionError(.invalidDerivationPath) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: Self.mnemonic,
                inputs: [
                    BitcoinSpendableUtxo(
                        derivationPath: "m/84'/2147483648'/0'/0/0",
                        txid: Self.txid,
                        valueSats: 51_000,
                        vout: 0
                    )
                ],
                outputs: [BitcoinPaymentOutput(address: Self.mainnetRecipient, valueSats: 50_000)],
                feeSats: 1_000
            )
        }
    }

    func testRejectsEmptyMnemonicBeforeSigning() {
        assertTransactionError(.invalidMnemonic) {
            _ = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: "",
                inputs: [BitcoinSpendableUtxo(txid: Self.txid, valueSats: 51_000, vout: 0)],
                outputs: [BitcoinPaymentOutput(address: Self.mainnetRecipient, valueSats: 50_000)],
                feeSats: 1_000
            )
        }
    }

    private func assertTransactionError(
        _ expected: BitcoinTransactionError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) {
        do {
            try block()
            XCTFail("Expected Bitcoin transaction error \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? BitcoinTransactionError, expected, file: file, line: line)
        }
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let mainnetAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let mainnetRecipient = "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m"
    private static let testnetAddress = "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl"
    private static let txid = String(repeating: "11", count: 32)
    private static let expectedTxid = "94c9b9d5070f24e06725b1000d9b1a0d46473d07b59088aca35e3d3da345023d"
    private static let expectedTxHex = "0200000000010111111111111111111111111111111111111111111111111111111111111111110100000000ffffffff0250c300000000000016001487ed12b988403af67cf36ea58b7454ab5d165ab436c2000000000000160014c0cebcd6c3d3ca8c75dc5ec62ebe55330ef910e202473044022009ec0c24a20c4346c6516065723e2e83e6a7e4dd278fb66e27f36d9108d7ef4c022077f115bfbd68a2bc7a4c100766d9cceaf5300bcfcdc775be0248e7fb5a58216801210330d54fd0dd420a6e5f8d3624f5f3482cae350f79d5f0753bf5beef9c2d91af3c00000000"
}
