import SSFUtils
import BigInt
import Foundation

class SwapAmount: Codable {
    var desired: BigUInt
    var slip: BigUInt
    let type: SwapVariant

    enum CodingKeysIn: String, CodingKey {
        case desired = "desiredAmountIn"
        case slip = "minAmountOut"
    }

    enum CodingKeysOut: String, CodingKey {
        case desired = "desiredAmountOut"
        case slip = "maxAmountIn"
    }

    init(type: SwapVariant, desired: BigUInt, slip: BigUInt) {
        self.desired = desired
        self.slip = slip
        self.type = type
    }

    public required init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeysIn.self),
           !container.allKeys.isEmpty {
            let slip = try container.decode(String.self, forKey: CodingKeysIn.slip)
            let desired = try container.decode(String.self, forKey: CodingKeysIn.desired)
            self.slip = BigUInt(string: slip) ?? 0
            self.desired = BigUInt(string: desired) ?? 0
            type = .desiredInput
        } else
        if let container = try? decoder.container(keyedBy: CodingKeysOut.self),
           !container.allKeys.isEmpty {
            let desired = try container.decode(String.self, forKey: CodingKeysOut.slip)
            let slip = try container.decode(String.self, forKey: CodingKeysOut.desired)
            self.slip = BigUInt(slip) ?? 0
            self.desired = BigUInt(desired) ?? 0
            type = .desiredOutput
        } else {
            let context = DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid CodingKey"
            )
            throw DecodingError.typeMismatch(SwapAmount.self, context)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch type {
        // please, mind that we encode .description, because metadata requires string, and @stringCodable somehow fails
        case .desiredOutput:
            var container = encoder.container(keyedBy: CodingKeysOut.self)
            try container.encode(desired.description, forKey: .desired)
            try container.encode(slip.description, forKey: .slip)
        case .desiredInput:
            var container = encoder.container(keyedBy: CodingKeysIn.self)
            try container.encode(desired.description, forKey: .desired)
            try container.encode(slip.description, forKey: .slip)
        }
    }
}

struct SwapCall: Codable {
    let dexId: String
    var inputAssetId: SoraAssetId
    var outputAssetId: SoraAssetId

    var amount: [SwapVariant: SwapAmount]
    let liquiditySourceType: [[String?]] // TBD liquiditySourceType.codable
    let filterMode: PolkaswapCallFilterModeType

    enum CodingKeys: String, CodingKey {
        case dexId
        case inputAssetId
        case outputAssetId
        case amount = "swapAmount"
        case liquiditySourceType = "selectedSourceTypes"
        case filterMode
    }
}

struct PolkaswapCallFilterModeType: Codable {
    var name: String
    var value: UInt?

    init(wrappedName: String, wrappedValue: UInt?) {
        name = wrappedName
        value = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            let dict = try container.decode([String?].self)
            let val1 = dict.first ?? "-"
            let val2 = dict.last ?? nil
            name = val1 ?? "-"

            if let value = val2 {
                self.value = UInt(value)
            }
        } catch {
            let dict = try container.decode(JSON.self)
            name = dict.arrayValue?.first?.stringValue ?? "-"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let value: [String?] = [name, nil]
        try container.encode(value)
    }
}

struct SoraAssetId: Codable {
    @ArrayCodable var value: String

    init(wrappedValue: String) {
        value = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: Data].self)

        value = dict["code"]?.toHex(includePrefix: true) ?? "-"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard
            let bytes = try? Data(hexStringSSF: value).map({ StringScaleMapper(value: $0) })
        else {
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Invalid encoding"
            )
            throw EncodingError.invalidValue(value, context)
        }
        try container.encode(["code": bytes])
    }
}

@propertyWrapper
struct ArrayCodable: Codable, Equatable {
    var wrappedValue: String

    init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let byteArray = try container.decode([StringScaleMapper<UInt8>].self)
        let value = byteArray.reduce("0x") { $0 + String(format: "%02x", $1.value) }

        wrappedValue = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        guard
            let bytes = try? Data(hexStringSSF: wrappedValue).map({ StringScaleMapper(value: $0) })
        else {
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Invalid encoding"
            )
            throw EncodingError.invalidValue(wrappedValue, context)
        }

        try container.encode(bytes)
    }
}
