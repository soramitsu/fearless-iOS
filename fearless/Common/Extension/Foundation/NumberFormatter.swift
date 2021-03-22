import Foundation

extension NumberFormatter {
    static var amount: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.alwaysShowsDecimalSeparator = false
        return numberFormatter
    }

    static var percent: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .percent
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.alwaysShowsDecimalSeparator = false
        numberFormatter.positivePrefix = numberFormatter.plusSign
        return numberFormatter
    }

    static var percentAPY: NumberFormatter {
        let numberFormatter = NumberFormatter.percent
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.positivePrefix = ""
        numberFormatter.percentSymbol = "% APY"
        return numberFormatter
    }

    static var quantity: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 0
        numberFormatter.alwaysShowsDecimalSeparator = false
        numberFormatter.usesGroupingSeparator = true
        return numberFormatter
    }
}
