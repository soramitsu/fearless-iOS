import XCTest
@testable import FearlessFoundation

final class NumberFormatterTests: XCTestCase {
    func testTokenFormatterAddsSuffixWithSeparator() {
        let formatter = TokenFormatter(
            decimalFormatter: FixedDecimalFormatter(value: "12.5"),
            tokenSymbol: "XOR",
            separator: " ",
            position: .suffix
        )

        XCTAssertEqual(formatter.stringFromDecimal(12.5), "12.5 XOR")
    }

    func testTokenFormatterLocale_whenSet_thenUpdatesUnderlyingDecimalFormatter() {
        let decimalFormatter = FixedDecimalFormatter(value: "12.5")
        let formatter = TokenFormatter(decimalFormatter: decimalFormatter, tokenSymbol: "XOR")

        formatter.locale = Locale(identifier: "fr_FR")

        XCTAssertEqual(decimalFormatter.locale.identifier, "fr_FR")
        XCTAssertEqual(formatter.locale.identifier, "fr_FR")
    }

    func testDynamicPrecisionFormatterExpandsPrecisionForSmallValues() {
        let formatter = DynamicPrecisionFormatter(preferredPrecision: 2)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(formatter.stringFromDecimal(0.0012), "0.001")
    }

    func testBigNumberFormatterUsesMatchingAbbreviation() {
        let formatter = BigNumberFormatter(
            abbreviations: [
                .defaultInitial,
                .defaultThousands
            ],
            precision: 1
        )
        formatter.locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(formatter.stringFromDecimal(2500), "2.5K")
    }

    func testBigNumberFormatterUsesLargeDefaultAbbreviations() {
        let formatter = BigNumberFormatter(
            abbreviations: [
                .defaultInitial,
                .defaultThousands,
                .defaultMillions,
                .defaultBillions
            ],
            precision: 1
        )
        formatter.locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(formatter.stringFromDecimal(2_500_000), "2.5M")
        XCTAssertEqual(formatter.stringFromDecimal(2_500_000_000), "2.5B")
    }

    func testBigNumberFormatterRejectsNegativeValues() {
        let formatter = BigNumberFormatter(abbreviations: [.defaultInitial])

        XCTAssertNil(formatter.stringFromDecimal(-1))
    }
}

private final class FixedDecimalFormatter: LocalizableDecimalFormatting {
    var locale: Locale! = Locale(identifier: "en_US_POSIX")

    private let value: String

    init(value: String) {
        self.value = value
    }

    func stringFromDecimal(_: Decimal) -> String? {
        value
    }
}
