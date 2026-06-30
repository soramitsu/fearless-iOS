import XCTest
@testable import fearless

final class BitcoinUtxoSelectorTests: XCTestCase {
    func testSelectsDeterministicHighestValueUtxosAndComputesChangeFee() throws {
        let result = try Self.selector.select(
            amountSats: 50_000,
            changeAddress: Self.mainnetAddress,
            feeRateSatPerVbyte: 2,
            utxos: [
                Self.spendable(txid: String(repeating: "55", count: 32), valueSats: 80_000, vout: 1),
                Self.spendable(txid: String(repeating: "11", count: 32), valueSats: 100_000, vout: 0)
            ]
        )

        XCTAssertEqual(result.selectedUtxos.map(\.txid), [String(repeating: "11", count: 32)])
        XCTAssertEqual(result.inputTotalSats, 100_000)
        XCTAssertEqual(result.feeSats, 282)
        XCTAssertEqual(result.changeAddress, Self.mainnetAddress)
        XCTAssertEqual(result.changeSats, 49_718)
        XCTAssertEqual(result.absorbedDustSats, 0)
    }

    func testAbsorbsUneconomicalDustRemainderIntoFee() throws {
        let result = try Self.selector.select(
            amountSats: 50_000,
            changeAddress: Self.mainnetAddress,
            feeRateSatPerVbyte: 1,
            utxos: [Self.spendable(valueSats: 50_210)]
        )

        XCTAssertEqual(result.feeSats, 210)
        XCTAssertEqual(result.absorbedDustSats, 100)
        XCTAssertEqual(result.changeSats, 0)
        XCTAssertNil(result.changeAddress)
    }

    func testFiltersUnconfirmedEsploraUtxosUnlessExplicitlyIncluded() throws {
        let utxos = [
            Self.esploraUtxo(valueSats: 1_000, confirmed: true),
            Self.esploraUtxo(valueSats: 2_000, confirmed: false, txid: String(repeating: "22", count: 32))
        ]

        XCTAssertEqual(
            try Self.selector.spendableUtxos(
                source: BitcoinUtxoSource(address: Self.mainnetAddress, derivationPath: "m/84'/0'/0'/0/0"),
                utxos: utxos
            ).count,
            1
        )
        XCTAssertEqual(
            try Self.selector.spendableUtxos(
                source: BitcoinUtxoSource(address: Self.mainnetAddress, derivationPath: "m/84'/0'/0'/0/0"),
                utxos: utxos,
                includeUnconfirmed: true
            ).count,
            2
        )
    }

    func testRejectsInsufficientFundsAndTooManyRequiredInputs() {
        assertSelectionError(.insufficientFunds) {
            _ = try Self.selector.select(
                amountSats: 50_000,
                changeAddress: Self.mainnetAddress,
                feeRateSatPerVbyte: 1,
                utxos: [Self.spendable(valueSats: 30_000)]
            )
        }
        assertSelectionError(.tooManyInputsRequired) {
            _ = try Self.selector.select(
                amountSats: 90_000,
                changeAddress: Self.mainnetAddress,
                feeRateSatPerVbyte: 1,
                maxInputs: 1,
                utxos: [
                    Self.spendable(txid: String(repeating: "11", count: 32), valueSats: 40_000, vout: 0),
                    Self.spendable(txid: String(repeating: "22", count: 32), valueSats: 40_000, vout: 1),
                    Self.spendable(txid: String(repeating: "33", count: 32), valueSats: 40_000, vout: 2)
                ]
            )
        }
    }

    func testRejectsMalformedSendSelectionInputsBeforeReturningPlan() {
        assertSelectionError(.amountBelowDust) {
            _ = try Self.selector.select(
                amountSats: 1,
                changeAddress: Self.mainnetAddress,
                feeRateSatPerVbyte: 1,
                utxos: [Self.spendable(valueSats: 1_000)]
            )
        }
        assertSelectionError(.invalidChangeAddress) {
            _ = try Self.selector.select(
                amountSats: 1_000,
                changeAddress: Self.testnetAddress,
                feeRateSatPerVbyte: 1,
                utxos: [Self.spendable(valueSats: 2_000)]
            )
        }
        assertSelectionError(.invalidFeeRate) {
            _ = try Self.selector.select(
                amountSats: 1_000,
                changeAddress: Self.mainnetAddress,
                feeRateSatPerVbyte: 0,
                utxos: [Self.spendable(valueSats: 2_000)]
            )
        }
        assertSelectionError(.invalidMaxInputs) {
            _ = try Self.selector.select(
                amountSats: 1_000,
                changeAddress: Self.mainnetAddress,
                feeRateSatPerVbyte: 1,
                maxInputs: 0,
                utxos: [Self.spendable(valueSats: 2_000)]
            )
        }
        assertSelectionError(.utxosRequired) {
            _ = try Self.selector.select(
                amountSats: 1_000,
                changeAddress: Self.mainnetAddress,
                feeRateSatPerVbyte: 1,
                utxos: []
            )
        }
    }

    func testRejectsAdversarialUtxoPayloads() {
        assertSelectionError(.invalidTxid) {
            try selectSingle(Self.spendable(txid: "../bad", valueSats: 2_000))
        }
        assertSelectionError(.invalidVout) {
            try selectSingle(Self.spendable(valueSats: 2_000, vout: -1))
        }
        assertSelectionError(.invalidUtxoValue) {
            try selectSingle(Self.spendable(valueSats: 0))
        }
        assertSelectionError(.invalidScriptPubKey) {
            try selectSingle(Self.spendable(valueSats: 2_000, scriptPubKey: "00gg"))
        }
        assertSelectionError(.invalidDerivationPath) {
            try selectSingle(Self.spendable(valueSats: 2_000, derivationPath: "../bad"))
        }
        assertSelectionError(.duplicateUtxo) {
            _ = try Self.selector.select(
                amountSats: 1_000,
                changeAddress: Self.mainnetAddress,
                feeRateSatPerVbyte: 1,
                utxos: [
                    Self.spendable(valueSats: 2_000),
                    Self.spendable(valueSats: 2_000)
                ]
            )
        }
    }

    func testRejectsMalformedSourceAddressesAndPaths() {
        assertSelectionError(.invalidSourceAddress) {
            _ = try Self.selector.spendableUtxos(
                source: BitcoinUtxoSource(address: Self.testnetAddress),
                utxos: [Self.esploraUtxo()]
            )
        }
        assertSelectionError(.invalidDerivationPath) {
            _ = try Self.selector.spendableUtxos(
                source: BitcoinUtxoSource(address: Self.mainnetAddress, derivationPath: "../bad"),
                utxos: [Self.esploraUtxo()]
            )
        }
    }

    private func selectSingle(_ utxo: BitcoinSpendableUtxo) throws {
        _ = try Self.selector.select(
            amountSats: 1_000,
            changeAddress: Self.mainnetAddress,
            feeRateSatPerVbyte: 1,
            utxos: [utxo]
        )
    }

    private func assertSelectionError(
        _ expected: BitcoinUtxoSelectionError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) {
        do {
            try block()
            XCTFail("Expected Bitcoin UTXO selection error \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? BitcoinUtxoSelectionError, expected, file: file, line: line)
        }
    }

    private static let selector = BitcoinUtxoSelector()
    private static let mainnetAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let testnetAddress = "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl"

    private static func spendable(
        txid: String = String(repeating: "11", count: 32),
        valueSats: Int64,
        vout: Int64 = 0,
        derivationPath: String? = nil,
        scriptPubKey: String? = nil
    ) -> BitcoinSpendableUtxo {
        BitcoinSpendableUtxo(
            address: mainnetAddress,
            derivationPath: derivationPath,
            scriptPubKey: scriptPubKey,
            txid: txid,
            valueSats: valueSats,
            vout: vout
        )
    }

    private static func esploraUtxo(
        valueSats: Int64 = 1_000,
        confirmed: Bool = true,
        txid: String = String(repeating: "11", count: 32)
    ) -> BitcoinEsploraUtxo {
        BitcoinEsploraUtxo(
            txid: txid,
            vout: 0,
            value: valueSats,
            status: BitcoinEsploraTxStatus(
                confirmed: confirmed,
                blockHash: nil,
                blockHeight: nil,
                blockTime: nil
            )
        )
    }
}
