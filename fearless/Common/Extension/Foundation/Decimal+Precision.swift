import Foundation
import BigInt

extension Decimal {
    static var decimalToBigUIntHandler: NSDecimalNumberHandler {
        NSDecimalNumberHandler(roundingMode: .down,
                               scale: 0,
                               raiseOnExactness: false,
                               raiseOnOverflow: false,
                               raiseOnUnderflow: false,
                               raiseOnDivideByZero: false)
    }

    static func fromSubstrateAmount(_ value: BigUInt, precision: Int16) -> Decimal? {
        let valueString = String(value)

        guard let decimalValue = Decimal(string: valueString) else {
            return nil
        }

        return (decimalValue as NSDecimalNumber).multiplying(byPowerOf10: -precision).decimalValue
    }

    func toSubstrateAmount(precision: Int16) -> BigUInt? {
        let valueString = (self as NSDecimalNumber)
            .multiplying(byPowerOf10: precision, withBehavior: Self.decimalToBigUIntHandler).stringValue
        return BigUInt(valueString)
    }

    static func fromSubstratePerbill(value: BigUInt) -> Decimal? {
        fromSubstrateAmount(value, precision: 9)
    }
}
