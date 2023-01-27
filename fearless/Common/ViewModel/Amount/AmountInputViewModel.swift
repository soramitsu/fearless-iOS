import Foundation

@objc protocol AmountInputViewModelObserver: AnyObject {
    func amountInputDidChange()
}

protocol AmountInputViewModelProtocol: AnyObject {
    var symbol: String { get }
    var displayAmount: String { get }
    var decimalAmount: Decimal? { get }
    var isValid: Bool { get }
    var observable: WalletViewModelObserverContainer<AmountInputViewModelObserver> { get }

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool
    func didUpdateAmount(to newAmount: Decimal)
}

extension AmountInputViewModelProtocol {
    func didUpdateAmount(to _: Decimal) {}
}

final class AmountInputViewModel: AmountInputViewModelProtocol, MoneyPresentable {
    static let zero: String = "0"

    var displayAmount: String {
        formattedAmount ?? AmountInputViewModel.zero
    }

    var decimalAmount: Decimal? {
        if amount.isEmpty || amount.last == "," || amount.last == "." {
            return nil
        }

        return Decimal(string: amount, locale: formatter.locale)
    }

    var isValid: Bool {
        if let value = Decimal(string: amount, locale: formatter.locale), value > 0 {
            return true
        } else {
            return false
        }
    }

    var precision: Int16

    private(set) var amount: String = "" {
        didSet {
            if amount != oldValue {
                observable.observers.forEach { $0.observer?.amountInputDidChange() }
            }
        }
    }

    let symbol: String
    let formatter: NumberFormatter
    let inputLocale: Locale

    var observable: WalletViewModelObserverContainer<AmountInputViewModelObserver>

    init(
        symbol: String,
        amount: Decimal?,
        formatter: NumberFormatter,
        inputLocale: Locale = Locale.current,
        precision: Int16 = 2
    ) {
        self.symbol = symbol
        self.formatter = formatter
        self.inputLocale = inputLocale
        self.precision = precision

        observable = WalletViewModelObserverContainer()

        if let amount = amount,
           let inputAmount = formatter.string(from: amount as NSNumber) {
            self.amount = set(inputAmount)
        }
    }

    public func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool {
        let replacement = transform(input: string, from: inputLocale)

        var newAmount = displayAmount

        if range.location == newAmount.count {
            newAmount = add(replacement)
        } else {
            newAmount = (newAmount as NSString).replacingCharacters(in: range, with: replacement)
            newAmount = set(newAmount)
        }

        let optionalAmountDecimal = !newAmount.isEmpty
            ? Decimal(string: newAmount, locale: formatter.locale)
            : Decimal.zero

        amount = newAmount

        return false
    }

    func didUpdateAmount(to newAmount: Decimal) {
        guard let inputAmount = formatter.string(from: newAmount as NSNumber) else { return }

        amount = inputAmount
    }
}
