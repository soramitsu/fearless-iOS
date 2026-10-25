import BigInt
import Foundation
import SSFUtils

public enum SoraAmountDecimalError: Error {
    case invalidStringValue
}

struct SoraAmountDecimal: Decodable, Equatable {
    let value: BigUInt

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let stringValue = try container.decode(String.self)

        guard let value = BigUInt(stringValue) else {
            throw SoraAmountDecimalError.invalidStringValue
        }

        self.value = value
    }
}
