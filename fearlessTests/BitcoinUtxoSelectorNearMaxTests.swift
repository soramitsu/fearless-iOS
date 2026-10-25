import XCTest
@testable import fearless

/// IOSUX-3 B5 and the replacement rule: sending "almost everything" must work when the only
/// valid transaction has no change output, the overpay that implies must stay bounded, and a
/// payment replacing an unresolved one must spend every coin of that one.
final class BitcoinUtxoSelectorNearMaxTests: XCTestCase {
    /// 1 sat/vB: one input and one output is 110 vB, with a change output 141 vB. A remainder
    /// of 350 sats is above the dust floor, yet the change it would leave (319) is below it.
    /// Before the fix this threw `insufficientFunds` although a no-change transaction is valid.
    func testAbsorbsABoundedRemainderWhenChangeWouldBeDust() throws {
        let result = try Self.selector.select(
            amountSats: 50000,
            changeAddress: Self.address,
            feeRateSatPerVbyte: 1,
            utxos: [Self.coin(valueSats: 50000 + 110 + 350)]
        )

        XCTAssertNil(result.changeAddress)
        XCTAssertEqual(result.changeSats, 0)
        XCTAssertEqual(result.absorbedDustSats, 350)
        XCTAssertEqual(result.feeSats, 460)
        XCTAssertEqual(result.inputTotalSats - result.feeSats, 50000)
    }

    func testAbsorbsAcrossSeveralCoinsAtAHigherRate() throws {
        // 2 inputs at 10 sat/vB: 1,780 sats without change, 2,090 with it.
        let result = try Self.selector.select(
            amountSats: 100_000,
            changeAddress: Self.address,
            feeRateSatPerVbyte: 10,
            utxos: [
                Self.coin(txid: String(repeating: "11", count: 32), valueSats: 60000),
                Self.coin(txid: String(repeating: "22", count: 32), valueSats: 100_000 + 1780 + 600 - 60000)
            ]
        )

        XCTAssertEqual(result.selectedUtxos.count, 2)
        XCTAssertNil(result.changeAddress)
        XCTAssertEqual(result.absorbedDustSats, 600)
        XCTAssertEqual(result.feeSats, 2380)
    }

    /// The absorbed amount is never more than a change output would have cost plus the dust
    /// floor, and an amount the coins cannot cover is still refused.
    func testOverpayIsAlwaysBoundedAndShortfallsAreRefused() throws {
        for feeRate in [1.0, 1.5, 2, 7.3, 25, 100] {
            let noChangeFee = Int64(ceil(110 * feeRate))
            let bound = Int64(ceil(31 * feeRate)) + BitcoinUtxoSelector.bitcoinP2wpkhDustSats

            for remainder in Int64(-50) ... bound + 400 {
                let coin = 200_000 + noChangeFee + remainder
                do {
                    let result = try Self.selector.select(
                        amountSats: 200_000,
                        changeAddress: Self.address,
                        feeRateSatPerVbyte: feeRate,
                        utxos: [Self.coin(valueSats: coin)]
                    )
                    XCTAssertGreaterThanOrEqual(remainder, 0, "rate \(feeRate) remainder \(remainder)")
                    XCTAssertEqual(result.inputTotalSats - result.feeSats - result.changeSats, 200_000)
                    if result.changeAddress == nil {
                        XCTAssertLessThanOrEqual(result.absorbedDustSats, bound, "rate \(feeRate) remainder \(remainder)")
                    } else {
                        XCTAssertGreaterThanOrEqual(result.changeSats, BitcoinUtxoSelector.bitcoinP2wpkhDustSats)
                    }
                } catch {
                    XCTAssertEqual(error as? BitcoinUtxoSelectionError, .insufficientFunds)
                    XCTAssertLessThan(remainder, 0, "rate \(feeRate) remainder \(remainder) must be payable")
                }
            }
        }
    }

    func testRequiredCoinsAreSpentEvenWhenALargerCoinWouldDo() throws {
        let stuck = Self.coin(txid: String(repeating: "aa", count: 32), valueSats: 20000)
        let large = Self.coin(txid: String(repeating: "bb", count: 32), valueSats: 900_000)

        let result = try Self.selector.select(
            amountSats: 50000,
            changeAddress: Self.address,
            feeRateSatPerVbyte: 2,
            utxos: [large, stuck],
            requiredOutpoints: [BitcoinOutpoint(txid: String(repeating: "AA", count: 32), vout: 0)]
        )

        XCTAssertEqual(Set(result.selectedUtxos.map(\.txid)), [stuck.txid, large.txid])
        XCTAssertEqual(result.selectedUtxos.first?.txid, stuck.txid)
    }

    func testRequiredCoinThatIsGoneIsReportedInsteadOfSilentlyDropped() {
        XCTAssertThrowsError(
            try Self.selector.select(
                amountSats: 50000,
                changeAddress: Self.address,
                feeRateSatPerVbyte: 2,
                utxos: [Self.coin(valueSats: 900_000)],
                requiredOutpoints: [BitcoinOutpoint(txid: String(repeating: "aa", count: 32), vout: 3)]
            )
        ) { error in
            XCTAssertEqual(error as? BitcoinUtxoSelectionError, .requiredInputUnavailable)
        }
    }

    /// A larger recipient output (Taproot, P2WSH) is priced at its real size, so the quoted
    /// rate is the rate actually paid.
    func testFeeUsesTheRecipientOutputSize() throws {
        let segwit = try Self.selector.select(
            amountSats: 50000,
            changeAddress: Self.address,
            feeRateSatPerVbyte: 2,
            utxos: [Self.coin(valueSats: 100_000)]
        )
        let taproot = try Self.selector.select(
            amountSats: 50000,
            changeAddress: Self.address,
            feeRateSatPerVbyte: 2,
            utxos: [Self.coin(valueSats: 100_000)],
            recipientOutputVbytes: BitcoinAddressSupport.Kind.p2tr.outputVbytes
        )

        XCTAssertEqual(segwit.feeSats, 282)
        XCTAssertEqual(taproot.feeSats, 282 + 2 * 12)
    }

    func testSweepIsEveryCoinIntoOneOutput() throws {
        let sweep = try Self.selector.sweep(
            feeRateSatPerVbyte: 2,
            utxos: [
                Self.coin(txid: String(repeating: "11", count: 32), valueSats: 70000),
                Self.coin(txid: String(repeating: "22", count: 32), valueSats: 30000)
            ]
        )

        // 11 + 2 x 68 + 31 = 178 vB.
        XCTAssertEqual(sweep.inputCount, 2)
        XCTAssertEqual(sweep.inputTotalSats, 100_000)
        XCTAssertEqual(sweep.feeSats, 356)
        XCTAssertEqual(sweep.maxSendableSats, 99644)

        // Sending exactly that amount selects every coin and leaves nothing over.
        let result = try Self.selector.select(
            amountSats: sweep.maxSendableSats,
            changeAddress: Self.address,
            feeRateSatPerVbyte: 2,
            utxos: [
                Self.coin(txid: String(repeating: "11", count: 32), valueSats: 70000),
                Self.coin(txid: String(repeating: "22", count: 32), valueSats: 30000)
            ]
        )
        XCTAssertEqual(result.feeSats, sweep.feeSats)
        XCTAssertNil(result.changeAddress)
        XCTAssertEqual(result.absorbedDustSats, 0)
    }

    private static let selector = BitcoinUtxoSelector()
    private static let address = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"

    private static func coin(
        txid: String = String(repeating: "11", count: 32),
        valueSats: Int64,
        vout: Int64 = 0
    ) -> BitcoinSpendableUtxo {
        BitcoinSpendableUtxo(
            address: address,
            derivationPath: "m/84'/0'/0'/0/0",
            txid: txid,
            valueSats: valueSats,
            vout: vout
        )
    }
}
