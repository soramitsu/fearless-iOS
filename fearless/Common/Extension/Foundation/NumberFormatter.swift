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

    static var percentPlain: NumberFormatter {
        let numberFormatter = percentBase
        numberFormatter.multiplier = 1
        return numberFormatter
    }

    static var percent: NumberFormatter {
        percentBase
    }

    static var signedPercent: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .percent
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.alwaysShowsDecimalSeparator = false
        numberFormatter.positivePrefix = numberFormatter.plusSign
        return numberFormatter
    }

    static var percentPlainAPY: NumberFormatter {
        let numberFormatter = percentBase
        numberFormatter.percentSymbol = "% APY"
        numberFormatter.multiplier = 1
        return numberFormatter
    }

    static var percentPlainAPR: NumberFormatter {
        let numberFormatter = percentBase
        numberFormatter.percentSymbol = "% APR"
        numberFormatter.multiplier = 1
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

    static var fiat: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesSignificantDigits = true
        return formatter
    }

    static var polkaswapBalance: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter
    }

    static func token(
        rounding: NumberFormatter.RoundingMode,
        usesIntGrouping: Bool = false
    ) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 8
        formatter.roundingMode = rounding
        formatter.usesGroupingSeparator = usesIntGrouping
        return formatter
    }

    static var nomisHours: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter
    }
}
