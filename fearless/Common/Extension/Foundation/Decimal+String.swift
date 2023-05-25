import Foundation
import SoraFoundation

extension Decimal {
    var stringWithPointSeparator: String {
        let separator = [NSLocale.Key.decimalSeparator: "."]
        var value = self

        return NSDecimalString(&value, separator)
    }

    func toString(locale: Locale?, minimumDigits: Int = 3, maximumDigits: Int = 8) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = minimumDigits
        formatter.maximumFractionDigits = maximumDigits
        return formatter.string(from: self as NSDecimalNumber)
    }

    func percentString(locale: Locale?) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.positivePrefix = formatter.plusSign
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber)
    }
}
