import Foundation
import WalletCore

/// Display formatting for fiat values, percentages and masked amounts.
public enum Money {
    /// What privacy mode shows instead of an amount.
    public static let mask = "••••"

    /// Fiat value in the user's locale. Values below one unit keep up to
    /// four significant digits so small prices do not print as zero.
    public static func fiat(_ value: Decimal, currency: FiatCurrency, locale: Locale = .current) -> String {
        let code = currency.code.uppercased()
        let magnitude = abs(value)
        if magnitude > 0, magnitude < 1 {
            return value.formatted(
                .currency(code: code).locale(locale).precision(.significantDigits(2...4))
            )
        }
        return value.formatted(.currency(code: code).locale(locale))
    }

    /// Fiat value at the currency's own precision, for estimates such as a
    /// fee: `$0.06`, or `< $0.01` when it would round to nothing.
    public static func fiatApproximate(_ value: Decimal, currency: FiatCurrency, locale: Locale = .current) -> String {
        let style = Decimal.FormatStyle.Currency(code: currency.code.uppercased(), locale: locale)
        let zero = Decimal(0).formatted(style)
        let text = value.formatted(style)
        guard value > 0, text == zero else { return text }
        // Too small to show at the currency's precision.
        let cent = Decimal(string: "0.01") ?? 0
        let unit: Decimal = cent.formatted(style) == zero ? 1 : cent
        return "< " + unit.formatted(style)
    }

    /// Whole-unit fiat value for tight places (chart labels).
    public static func fiatCompact(_ value: Decimal, currency: FiatCurrency, locale: Locale = .current) -> String {
        value.formatted(
            .currency(code: currency.code.uppercased()).locale(locale).precision(.fractionLength(0))
        )
    }

    /// Signed percentage such as `+2.34%` or `−1.20%`.
    public static func percent(_ value: Decimal, locale: Locale = .current) -> String {
        (value / 100).formatted(
            .percent.locale(locale).precision(.fractionLength(2)).sign(strategy: .always(includingZero: false))
        )
    }

    /// Unsigned share such as `42.5%`.
    public static func share(_ fraction: Decimal, locale: Locale = .current) -> String {
        fraction.formatted(.percent.locale(locale).precision(.fractionLength(0...1)))
    }

    /// Token amount with its symbol, e.g. `12.5 DOT`.
    public static func token(_ amount: TokenAmount, symbol: String, maximumFractionDigits: Int = 4, locale: Locale = .current) -> String {
        "\(amount.formatted(maximumFractionDigits: maximumFractionDigits, locale: locale)) \(symbol)"
    }

    /// Fraction digits to show for an asset: stablecoins read like money.
    public static func displayDigits(isStablecoin: Bool, decimals: Int) -> (minimum: Int, maximum: Int) {
        if isStablecoin { return (min(2, decimals), min(2, decimals)) }
        return (0, min(4, decimals))
    }
}

/// Address shortening and grouping.
public enum AddressFormat {
    /// `15oF4uVJ…5KNHr6`: head and tail with an ellipsis between.
    public static func truncated(_ address: String, head: Int = 8, tail: Int = 6) -> String {
        guard address.count > head + tail + 1 else { return address }
        return "\(address.prefix(head))…\(address.suffix(tail))"
    }

    /// Groups of `size` characters separated by spaces, for careful reading.
    public static func grouped(_ address: String, size: Int = 4) -> String {
        guard size > 0 else { return address }
        var groups: [Substring] = []
        var index = address.startIndex
        while index < address.endIndex {
            let end = address.index(index, offsetBy: size, limitedBy: address.endIndex) ?? address.endIndex
            groups.append(address[index..<end])
            index = end
        }
        return groups.joined(separator: " ")
    }

    /// Fills a `{hash}`-style explorer template; nil when it does not produce a web URL.
    public static func webURL(_ url: URL?) -> URL? {
        guard let url, let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return url
    }
}
