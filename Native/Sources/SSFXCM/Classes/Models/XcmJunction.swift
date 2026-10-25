import BigInt
import Foundation
import SSFModels
import SSFUtils

enum XcmJunction: Codable {
    case parachain(_ paraId: ParaId)
    case accountId32(AccountId32Value)
    case accountIndex64(AccountIndexValue)
    case accountKey20(AccountId20Value)
    case palletInstance(_ index: UInt8)
    case generalIndex(_ index: BigUInt)
    case generalKey(_ key: Data)
    case generalKeyV3(_ key: GeneralKeyV3)
    case onlyChild

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .parachain(paraId):
            try container.encode("Parachain")
            try container.encode(StringCodable(wrappedValue: paraId))
        case let .accountId32(value):
            try container.encode("AccountId32")
            try container.encode(value)
        case let .accountIndex64(value):
            try container.encode("AccountIndex64")
            try container.encode(value)
        case let .accountKey20(value):
            try container.encode("AccountKey20")
            try container.encode(value)
        case let .palletInstance(index):
            try container.encode("PalletInstance")
            try container.encode(StringCodable(wrappedValue: index))
        case let .generalIndex(index):
            try container.encode("GeneralIndex")
            try container.encode(StringCodable(wrappedValue: index))
        case let .generalKey(key):
            try container.encode("GeneralKey")
            try container.encode(BytesCodable(wrappedValue: key))
        case let .generalKeyV3(key):
            try container.encode("GeneralKey")
            try container.encode(key)
        case .onlyChild:
            try container.encode("OnlyChild")
            try container.encode(JSON.null)
        }
    }

    enum CodingKeys: CodingKey {
        case parachain
        case accountId32
        case accountIndex64
        case accountKey20
        case palletInstance
        case generalIndex
        case generalKeyV1
        case generalKeyV3
        case onlyChild
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var allKeys = ArraySlice(container.allKeys)
        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
            throw DecodingError.typeMismatch(
                XcmJunction.self,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid number of keys found, expected one.",
                    underlyingError: nil
                )
            )
        }
        switch onlyKey {
        case .parachain:
            self = try XcmJunction.parachain(container.decode(UInt32.self, forKey: .parachain))
        case .accountId32:
            let accountId32Value = try container.decode(AccountId32Value.self, forKey: .accountId32)
            self = XcmJunction.accountId32(accountId32Value)
        case .accountIndex64:
            let accountIndex64Value = try container.decode(
                AccountIndexValue.self,
                forKey: .accountIndex64
            )
            self = XcmJunction.accountIndex64(accountIndex64Value)
        case .accountKey20:
            let accountId20Value = try container.decode(
                AccountId20Value.self,
                forKey: .accountKey20
            )
            self = XcmJunction.accountKey20(accountId20Value)
        case .palletInstance:
            self = try XcmJunction.palletInstance(container.decode(
                UInt8.self,
                forKey: .palletInstance
            ))
        case .generalIndex:
            let index = try container.decode(Int.self, forKey: .generalIndex)
            guard let generalIndex = BigUInt("\(index)") else {
                let context = DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "general index not found",
                    underlyingError: nil
                )
                throw DecodingError.valueNotFound(BigUInt.self, context)
            }
            self = XcmJunction.generalIndex(generalIndex)
        case .generalKeyV1:
            let hexString = try container.decode(String.self, forKey: .generalKeyV1)
            let generalKey = (try? Data(hexStringSSF: hexString)) ?? Data(hexString.utf8)
            self = XcmJunction.generalKey(generalKey)
        case .generalKeyV3:
            let generalKey = try container.decode(GeneralKeyV3.self, forKey: .generalKeyV3)
            self = XcmJunction.generalKeyV3(generalKey)
        case .onlyChild:
            self = XcmJunction.onlyChild
        }
    }

    func isParachain() -> Bool {
        switch self {
        case .parachain:
            return true
        default:
            return false
        }
    }
}

extension XcmJunction: Equatable {
    static func == (lhs: XcmJunction, rhs: XcmJunction) -> Bool {
        switch (lhs, rhs) {
        case let (.parachain(lhsValue), .parachain(rhsValue)):
            return lhsValue == rhsValue
        case let (.accountId32(lhsValue), .accountId32(rhsValue)):
            return lhsValue == rhsValue
        case let (.accountIndex64(lhsValue), .accountIndex64(rhsValue)):
            return lhsValue == rhsValue
        case let (.accountKey20(lhsValue), .accountKey20(rhsValue)):
            return lhsValue == rhsValue
        case let (.palletInstance(lhsValue), .palletInstance(rhsValue)):
            return lhsValue == rhsValue
        case let (.generalIndex(lhsValue), .generalIndex(rhsValue)):
            return lhsValue == rhsValue
        case let (.generalKey(lhsValue), .generalKey(rhsValue)):
            return lhsValue == rhsValue
        case let (.generalKeyV3(lhsValue), .generalKeyV3(rhsValue)):
            return lhsValue == rhsValue
        case (.onlyChild, .onlyChild):
            return true
        default:
            return false
        }
    }
}
