import Foundation

enum AmountDecimalError: Error {
    case invalidStringValue
}

struct AmountDecimal: Codable, Equatable {
    let decimalValue: Decimal

    var stringValue: String {
        (decimalValue as NSNumber).stringValue
    }

    init(value: Decimal) {
        decimalValue = value
    }

    init?(string: String) {
        guard let value = Decimal(string: string) else {
            return nil
        }

        self.init(value: value)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let stringValue = try container.decode(String.self)

        guard let value = Decimal(string: stringValue) else {
            throw AmountDecimalError.invalidStringValue
        }

        decimalValue = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}
