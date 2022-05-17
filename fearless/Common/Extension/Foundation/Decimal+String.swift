import Foundation
import SoraFoundation

extension Decimal {
    var stringWithPointSeparator: String {
        let separator = [NSLocale.Key.decimalSeparator: "."]
        var value = self

        return NSDecimalString(&value, separator)
    }

    func toString(locale: Locale?, digits: Int = 2) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
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
