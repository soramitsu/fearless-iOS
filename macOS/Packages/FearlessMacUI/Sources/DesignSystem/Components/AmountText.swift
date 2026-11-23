import SwiftUI
import WalletCore

/// A token amount in monospaced digits. Privacy mode masks it; VoiceOver
/// reads the full amount with its symbol (or "hidden").
public struct AmountText: View {
    public enum Sign {
        case none, plus, minus

        var prefix: String {
            switch self {
            case .none: return ""
            case .plus: return "+"
            case .minus: return "−"
            }
        }
    }

    private let amount: TokenAmount
    private let symbol: String?
    private let minimumFractionDigits: Int
    private let maximumFractionDigits: Int
    private let sign: Sign

    @Environment(\.balancesHidden) private var hidden
    @Environment(\.locale) private var locale

    public init(_ amount: TokenAmount, symbol: String? = nil, minimumFractionDigits: Int = 0, maximumFractionDigits: Int = 4, sign: Sign = .none) {
        self.amount = amount
        self.symbol = symbol
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
        self.sign = sign
    }

    public var body: some View {
        Text(hidden ? Money.mask : visibleText)
            .monospacedDigit()
            .accessibilityLabel(hidden ? "Amount hidden" : spokenText)
    }

    private var number: String {
        amount.formatted(maximumFractionDigits: maximumFractionDigits, minimumFractionDigits: minimumFractionDigits, locale: locale)
    }

    private var visibleText: String {
        let body = sign.prefix + number
        guard let symbol else { return body }
        return "\(body) \(symbol)"
    }

    private var spokenText: String {
        let direction: String
        switch sign {
        case .none: direction = ""
        case .plus: direction = "plus "
        case .minus: direction = "minus "
        }
        return direction + number + (symbol.map { " \($0)" } ?? "")
    }
}

/// A fiat value in the selected currency and the user's locale.
public struct FiatText: View {
    private let value: Decimal?
    private let currency: FiatCurrency
    private let placeholder: String
    private let isPrivate: Bool

    @Environment(\.balancesHidden) private var balancesHidden
    @Environment(\.locale) private var locale

    /// - Parameter isPrivate: false for figures that say nothing about the
    ///   user's holdings (market prices); those are never masked.
    public init(_ value: Decimal?, currency: FiatCurrency, placeholder: String = "—", isPrivate: Bool = true) {
        self.value = value
        self.currency = currency
        self.placeholder = placeholder
        self.isPrivate = isPrivate
    }

    private var hidden: Bool { isPrivate && balancesHidden }

    public var body: some View {
        Text(text)
            .monospacedDigit()
            .accessibilityLabel(accessibilityText)
    }

    private var text: String {
        guard let value else { return placeholder }
        return hidden ? Money.mask : Money.fiat(value, currency: currency, locale: locale)
    }

    private var accessibilityText: String {
        guard let value else { return "No value" }
        return hidden ? "Value hidden" : Money.fiat(value, currency: currency, locale: locale)
    }
}

/// A 24-hour change with its direction as colour, arrow and sign, so the
/// meaning never depends on colour alone.
public struct ChangeText: View {
    private let percent: Decimal?

    @Environment(\.locale) private var locale

    public init(percent: Decimal?) {
        self.percent = percent
    }

    public var body: some View {
        if let percent {
            HStack(spacing: 2) {
                Image(systemName: percent < 0 ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                    .font(.system(size: 7))
                    .opacity(percent == 0 ? 0 : 1)
                Text(Money.percent(percent, locale: locale))
                    .monospacedDigit()
            }
            .foregroundStyle(percent < 0 ? BrandColor.loss : (percent > 0 ? BrandColor.gain : Color.secondary))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(percent < 0 ? "Down \(Money.percent(-percent, locale: locale))" : "Up \(Money.percent(percent, locale: locale))")
        } else {
            Text("—").foregroundStyle(.tertiary).accessibilityLabel("No change data")
        }
    }
}
