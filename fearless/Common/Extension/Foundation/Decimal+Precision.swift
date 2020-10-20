import Foundation
import BigInt

extension Decimal {
    static func fromSubstrateAmount(_ value: BigUInt, precision: Int16) -> Decimal? {
        let valueString = String(value)

        guard let decimalValue = Decimal(string: valueString) else {
            return nil
        }

        return (decimalValue as NSDecimalNumber).multiplying(byPowerOf10: -precision).decimalValue
    }

    func toSubstrateAmount(precision: Int16) -> BigUInt? {
        let valueString = (self as NSDecimalNumber).multiplying(byPowerOf10: precision).stringValue
        return BigUInt(valueString)
    }
}
