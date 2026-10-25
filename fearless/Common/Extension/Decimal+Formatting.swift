import Foundation

extension Decimal {
    func string(maximumFractionDigits: Int = 2) -> String {
        let decimalString = "\(self)"

        var resultString: String = ""
        var pointPassed: Bool = false
        var nonZeroDecimalCounter: Int = 0
        for char in decimalString {
            guard nonZeroDecimalCounter < maximumFractionDigits else {
                break
            }

            resultString.append(char)
            if char == "." { pointPassed = true }
            guard pointPassed else {
                continue
            }

            if nonZeroDecimalCounter > 0 {
                nonZeroDecimalCounter += 1
            } else if char != "0", char != "." {
                nonZeroDecimalCounter += 1
            }
        }

        return resultString
    }
}
