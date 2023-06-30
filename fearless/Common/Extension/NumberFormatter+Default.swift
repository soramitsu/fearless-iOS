import Foundation
import SoraFoundation

public enum NumberFormatterUsageCase {
    case listCrypto
    case listCryptoWith(minimumFractionDigits: Int, maximumFractionDigits: Int)
    case detailsCrypto
    case fiat
    case percent
    case inputCrypto
    case inputFiat
}

public extension NumberFormatter {
    static func formatter(
        for usageCase: NumberFormatterUsageCase,
        locale: Locale,
        rounding: NumberFormatter.RoundingMode = .down,
        usesIntGrouping: Bool = false
    ) -> NumberFormatter {
        switch usageCase {
        case .listCrypto:
            return NumberFormatter.defaultListCryptoFormatter(
                locale: locale,
                rounding: rounding,
                usesIntGrouping: usesIntGrouping
            )
        case let .listCryptoWith(minimumFractionDigits, maximumFractionDigits):
            return NumberFormatter.defaultListCryptoFormatter(
                locale: locale,
                rounding: rounding,
                usesIntGrouping: usesIntGrouping,
                minimumFractionDigits: minimumFractionDigits,
                maximumFractionDigits: maximumFractionDigits
            )
        case .detailsCrypto:
            return NumberFormatter.defaultDetailsCryptoFormatter(
                locale: locale,
                rounding: rounding,
                usesIntGrouping: usesIntGrouping
            )
        case .fiat:
            return NumberFormatter.defaultFiatFormatter(locale: locale)
        case .percent:
            return NumberFormatter.defaultPercentFormatter(locale: locale)
        case .inputCrypto:
            return NumberFormatter.defaultInputCryptoFormatter(locale: locale)
        case .inputFiat:
            return NumberFormatter.defaultInputFiatFormatter(locale: locale)
        }
    }

    private static func defaultListCryptoFormatter(
        locale: Locale,
        rounding: NumberFormatter.RoundingMode = .down,
        usesIntGrouping: Bool = false,
        minimumFractionDigits: Int = 3,
        maximumFractionDigits: Int = 8
    ) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.roundingMode = rounding
        formatter.usesGroupingSeparator = usesIntGrouping
        return formatter
    }

    private static func defaultDetailsCryptoFormatter(
        locale: Locale,
        rounding: NumberFormatter.RoundingMode = .down,
        usesIntGrouping: Bool = false
    ) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 8
        formatter.roundingMode = rounding
        formatter.usesGroupingSeparator = usesIntGrouping
        return formatter
    }

    private static func defaultFiatFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private static func defaultPercentFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .percent
        formatter.minimumIntegerDigits = 1
        formatter.roundingMode = .down
        formatter.usesGroupingSeparator = true
        formatter.alwaysShowsDecimalSeparator = false
        return formatter
    }

    private static func defaultInputCryptoFormatter(
        locale: Locale,
        rounding: NumberFormatter.RoundingMode = .down,
        usesIntGrouping: Bool = false
    ) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumIntegerDigits = 1
        formatter.usesGroupingSeparator = usesIntGrouping
        formatter.roundingMode = rounding
        formatter.alwaysShowsDecimalSeparator = false
        formatter.maximumFractionDigits = 8
        return formatter
    }

    private static func defaultInputFiatFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumIntegerDigits = 1
        formatter.usesGroupingSeparator = true
        formatter.roundingMode = .down
        formatter.alwaysShowsDecimalSeparator = false
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

public extension NumberFormatter {
    static func decimalFormatter(
        precision _: Int,
        rounding: NumberFormatter.RoundingMode,
        usesIntGrouping: Bool = false,
        usageCase: NumberFormatterUsageCase,
        locale: Locale
    ) -> NumberFormatter {
        let formatter = formatter(for: usageCase, locale: locale)
        formatter.numberStyle = .decimal
        formatter.minimumIntegerDigits = 1
        formatter.roundingMode = rounding
        formatter.usesGroupingSeparator = usesIntGrouping
        formatter.alwaysShowsDecimalSeparator = false

        return formatter
    }
}
