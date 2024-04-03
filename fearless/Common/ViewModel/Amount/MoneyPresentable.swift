import Foundation

protocol MoneyPresentable {
    var formatter: NumberFormatter { get }
    var amount: String { get }
    var precision: Int16 { get }

    func transform(input: String, from locale: Locale) -> String
}

private enum MoneyPresentableConstants {
    static let singleZero = "0"
}

extension MoneyPresentable {
    var formattedAmount: String? {
        guard !amount.isEmpty else {
            return ""
        }

        guard let decimalAmount = Decimal(string: amount, locale: formatter.locale) else {
            return nil
        }

        var amountFormatted = formatter.string(from: decimalAmount as NSDecimalNumber)
        let separator = decimalSeparator()

        if amount.hasSuffix(separator) {
            amountFormatted?.append(separator)
        } else {
            let amountParts = amount.components(separatedBy: separator)
            let formattedParts = amountFormatted?.components(separatedBy: separator)

            if amountParts.count == 2, formattedParts?.count == 1 {
                // add tralling zeros including decimal separator
                let trallingZeros = String((0 ..< amountParts[1].count).map { _ in
                    Character(MoneyPresentableConstants.singleZero)
                })

                amountFormatted?.append("\(separator)\(trallingZeros)")
            } else if amountParts.count == 2, formattedParts?.count == 2 {
                // check whether tralling decimal zeros were cut during formatting
                if let decimalCount = formattedParts?[1].count, decimalCount < amountParts[1].count {
                    let zerosCount = amountParts[1].count - decimalCount
                    let trallingZeros = String((0 ..< zerosCount).map { _ in
                        Character(MoneyPresentableConstants.singleZero)
                    })

                    amountFormatted?.append("\(trallingZeros)")
                }
            }
        }

        return amountFormatted
    }

    private func decimalSeparator() -> String {
        formatter.decimalSeparator!
    }

    private func groupingSeparator() -> String {
        formatter.groupingSeparator!
    }

    private func notEligibleSet() -> CharacterSet {
        CharacterSet.decimalDigits
            .union(CharacterSet(charactersIn: "\(decimalSeparator())\(groupingSeparator())")).inverted
    }

    private func isValid(amount: String) -> Bool {
        let components = amount.components(separatedBy: decimalSeparator())

        return !((precision == 0 && components.count > 1) ||
            components.count > 2 ||
            (components.count == 2 && components[1].count > precision))
    }

    func add(_ amount: String) -> String {
        guard amount.rangeOfCharacter(from: notEligibleSet()) == nil else {
            return self.amount
        }

        var newAmount = (self.amount + amount).replacingOccurrences(
            of: groupingSeparator(),
            with: ""
        )

        if newAmount.hasPrefix(decimalSeparator()) {
            newAmount = "\(MoneyPresentableConstants.singleZero)\(newAmount)"
        }

        return isValid(amount: newAmount) ? newAmount : self.amount
    }

    func set(_ amount: String) -> String {
        guard amount.rangeOfCharacter(from: notEligibleSet()) == nil else {
            return self.amount
        }

        var settingAmount = amount.replacingOccurrences(
            of: groupingSeparator(),
            with: ""
        )

        if settingAmount.hasPrefix(decimalSeparator()) {
            settingAmount = "\(MoneyPresentableConstants.singleZero)\(settingAmount)"
        }

        return isValid(amount: settingAmount) ? settingAmount : self.amount
    }

    func transform(input: String, from locale: Locale) -> String {
        var result = input

        if let localeGroupingSeparator = locale.groupingSeparator {
            result = result.replacingOccurrences(of: localeGroupingSeparator, with: "")
        }

        if let localeDecimalSeparator = locale.decimalSeparator,
           localeDecimalSeparator != decimalSeparator() {
            result = result.replacingOccurrences(
                of: localeDecimalSeparator,
                with: decimalSeparator()
            )
        }

        if result.isEmpty {
            result = MoneyPresentableConstants.singleZero
        }

        return result
    }
}
