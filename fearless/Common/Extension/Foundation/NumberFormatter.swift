import Foundation

extension NumberFormatter {
    static var amount: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.roundingMode = .down
        numberFormatter.alwaysShowsDecimalSeparator = false
        return numberFormatter
    }

    static var percentBase: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .percent
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.roundingMode = .down
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
        let numberFormatter = percentBase
        numberFormatter.percentSymbol = "% APY"
        return numberFormatter
    }

    static var positivePercentAPY: NumberFormatter {
        let numberFormatter = percentBase
        numberFormatter.percentSymbol = "% APY"
        numberFormatter.positivePrefix = numberFormatter.plusSign
        return numberFormatter
    }

    static var positivePercentAPR: NumberFormatter {
        let numberFormatter = percentBase
        numberFormatter.percentSymbol = "% APR"
        numberFormatter.positivePrefix = numberFormatter.plusSign
        return numberFormatter
    }

    static var percentSingle: NumberFormatter {
        let numberFormatter = percentBase
        numberFormatter.percentSymbol = "%"
        numberFormatter.minimumFractionDigits = 0
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
