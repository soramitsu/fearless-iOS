import Foundation
import BigInt

extension Decimal {
    static func fromKusamaAmount(_ value: BigUInt) -> Decimal? {
        let valueString = String(value)

        guard let decimalValue = Decimal(string: valueString) else {
            return nil
        }

        return (decimalValue as NSDecimalNumber).multiplying(byPowerOf10: -12).decimalValue
    }
}
