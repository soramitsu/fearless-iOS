import Foundation
import SoraFoundation

enum FormatterLocale {
    case japanese
    case usual
}

protocol AssetBalanceFormatterFactoryProtocol {
    func createInputFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<NumberFormatter>

    func createInputFormatter(
        maximumFractionDigits: Int
    ) -> LocalizableResource<NumberFormatter>

    func createDisplayFormatter(
        for info: AssetBalanceDisplayInfo,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<LocalizableDecimalFormatting>

    func createTokenFormatter(
        for info: AssetBalanceDisplayInfo,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<TokenFormatter>

    func createFeeTokenFormatter(
        for info: AssetBalanceDisplayInfo,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<TokenFormatter>
}

class AssetBalanceFormatterFactory {
    private func createTokenFormatterCommon(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<TokenFormatter> {
        LocalizableResource { locale in
            let numberFormatter = NumberFormatter.formatter(for: usageCase, locale: locale)
            let formatterLocale: FormatterLocale = locale.identifier == "ja" ? .japanese : .usual
            let formatter = self.createCompoundFormatter(
                for: info.displayPrecision,
                roundingMode: roundingMode,
                formatter: numberFormatter,
                for: formatterLocale
            )

            let tokenFormatter = TokenFormatter(
                decimalFormatter: formatter,
                tokenSymbol: info.symbol,
                separator: info.symbolValueSeparator,
                position: info.symbolPosition
            )

            tokenFormatter.locale = locale
            return tokenFormatter
        }
    }

    // swiftlint:disable function_body_length
    private func createCompoundFormatter(
        for _: UInt16,
        roundingMode: NumberFormatter.RoundingMode = .down,
        formatter: NumberFormatter,
        for locale: FormatterLocale
    ) -> LocalizableDecimalFormatting {
        let abbreviations: [BigNumberAbbreviation]
        switch locale {
        case .japanese:
            abbreviations = [
                BigNumberAbbreviation(
                    threshold: 0,
                    divisor: 1.0,
                    suffix: "",
                    formatter: formatter
                ),
                BigNumberAbbreviation(
                    threshold: 1,
                    divisor: 1.0,
                    suffix: "",
                    formatter: formatter
                ),
                BigNumberAbbreviation(
                    threshold: 10,
                    divisor: 1.0,
                    suffix: "",
                    formatter: formatter
                ),
                BigNumberAbbreviation(
                    threshold: 10000,
                    divisor: 10000.0,
                    suffix: "万",
                    formatter: nil
                ),
                BigNumberAbbreviation(
                    threshold: 100_000_000,
                    divisor: 100_000_000.0,
                    suffix: "億",
                    formatter: nil
                ),
                BigNumberAbbreviation(
                    threshold: 1_000_000_000_000,
                    divisor: 1_000_000_000_000.0,
                    suffix: "兆",
                    formatter: nil
                )
            ]
        case .usual:
            abbreviations = [
                BigNumberAbbreviation(
                    threshold: 0,
                    divisor: 1.0,
                    suffix: "",
                    formatter: formatter
                ),
                BigNumberAbbreviation(
                    threshold: 1,
                    divisor: 1.0,
                    suffix: "",
                    formatter: formatter
                ),
                BigNumberAbbreviation(
                    threshold: 10,
                    divisor: 1.0,
                    suffix: "",
                    formatter: formatter
                ),
                BigNumberAbbreviation(
                    threshold: 1_000_000,
                    divisor: 1_000_000.0,
                    suffix: "M",
                    formatter: nil
                ),
                BigNumberAbbreviation(
                    threshold: 1_000_000_000,
                    divisor: 1_000_000_000.0,
                    suffix: "B",
                    formatter: nil
                ),
                BigNumberAbbreviation(
                    threshold: 1_000_000_000_000,
                    divisor: 1_000_000_000_000.0,
                    suffix: "T",
                    formatter: nil
                )
            ]
        }

        return BigNumberFormatter(
            abbreviations: abbreviations,
            precision: 2,
            rounding: roundingMode,
            usesIntGrouping: true
        )
    }
}

extension AssetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol {
    func createInputFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.maximumFractionDigits = Int(info.assetPrecision)
        return formatter.localizableResource()
    }

    func createInputFormatter(
        maximumFractionDigits: Int
    ) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.localizableResource()
    }

    func createDisplayFormatter(
        for info: AssetBalanceDisplayInfo,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<LocalizableDecimalFormatting> {
        LocalizableResource { locale in
            let numberFormatter = NumberFormatter.formatter(for: usageCase, locale: locale)
            let formatter = self.createCompoundFormatter(
                for: info.displayPrecision,
                formatter: numberFormatter,
                for: .usual
            )
            formatter.locale = locale
            return formatter
        }
    }

    func createTokenFormatter(
        for info: AssetBalanceDisplayInfo,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<TokenFormatter> {
        createTokenFormatterCommon(for: info, roundingMode: .down, usageCase: usageCase)
    }

    func createFeeTokenFormatter(
        for info: AssetBalanceDisplayInfo,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<TokenFormatter> {
        createTokenFormatterCommon(for: info, roundingMode: .up, usageCase: usageCase)
    }
}
