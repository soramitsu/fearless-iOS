import XCTest
@testable import fearless

final class WalletSendConfirmTests: XCTestCase {
    func testTonUnknownOutcomeRecoveryAcceptsExactLowercaseHash() throws {
        let hash = String(repeating: "0123456789abcdef", count: 4)

        let recovery = try XCTUnwrap(
            TonUnknownOutcomeRecoveryModel(messageHashHex: hash)
        )

        XCTAssertEqual(recovery.messageHashHex, hash)
    }

    func testTonUnknownOutcomeRecoveryRejectsMalformedOrDisplaySpoofedHashes() {
        let malformedHashes = [
            "",
            String(repeating: "0", count: 63),
            String(repeating: "0", count: 65),
            String(repeating: "A", count: 64),
            String(repeating: "g", count: 64),
            String(repeating: "０", count: 64),
            String(repeating: "0", count: 63) + "\n",
            String(repeating: "0", count: 32) + "\u{200B}" + String(repeating: "0", count: 31)
        ]

        for hash in malformedHashes {
            XCTAssertNil(
                TonUnknownOutcomeRecoveryModel(messageHashHex: hash),
                hash.debugDescription
            )
        }
    }

    func testTonExactFeeFormatterPreservesTheNinthDecimalAcrossLocales() throws {
        let exactOneNanoton = try XCTUnwrap(Decimal(string: "0.000000001"))
        let exactNinthDigit = try XCTUnwrap(Decimal(string: "0.100000001"))
        let roundedNeighbor = try XCTUnwrap(Decimal(string: "0.1"))
        let locales = ["en_US", "id_ID", "ja_JP", "pt_PT", "ru_RU", "tr_TR", "vi_VN", "zh_Hans"]

        for identifier in locales {
            let formatter = NumberFormatter.formatter(
                for: .exactCrypto(fractionDigits: 9),
                locale: Locale(identifier: identifier)
            )
            let oneNanoton = try XCTUnwrap(
                formatter.string(from: NSDecimalNumber(decimal: exactOneNanoton))
            )
            let ninthDigit = try XCTUnwrap(
                formatter.string(from: NSDecimalNumber(decimal: exactNinthDigit))
            )
            let neighbor = try XCTUnwrap(
                formatter.string(from: NSDecimalNumber(decimal: roundedNeighbor))
            )

            XCTAssertNotEqual(oneNanoton, formatter.string(from: 0), identifier)
            XCTAssertNotEqual(ninthDigit, neighbor, identifier)
            XCTAssertEqual(
                formatter.number(from: oneNanoton)?.decimalValue,
                exactOneNanoton,
                identifier
            )
            XCTAssertEqual(
                formatter.number(from: ninthDigit)?.decimalValue,
                exactNinthDigit,
                identifier
            )
        }
    }
}
