import Foundation
import SSFUtils
import BigInt

struct BondCall: Codable {
    enum CodingKeys: String, CodingKey {
        case controller
        case value
        case payee
    }

    var controller: MultiAddress
    @StringCodable var value: BigUInt
    var payee: RewardDestinationArg

    init(controller: MultiAddress, value: BigUInt, payee: RewardDestinationArg) {
        self.controller = controller
        self.value = value
        self.payee = payee
    }

//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//
//        controller = try container.decode(MultiAddress.self, forKey: .controller)
//        value = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .value).value
//        payee = try container.decode(RewardDestinationArg.self, forKey: .payee)
//    }
//
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        if let accountId = controller.accountId {
//            try container.encode(accountId.toHexString(), forKey: .controller)
//        }
//        try container.encode(StringScaleMapper(value: value), forKey: .value)
//        try container.encode(payee, forKey: .payee)
//    }
}

struct BondCallV2: Codable {
    @StringCodable var value: BigUInt
    var payee: RewardDestinationArg
}

enum RewardDestinationArg: Equatable {
    static let stakedField = "Staked"
    static let stashField = "Stash"
    static let controllerField = "Controller"
    static let accountField = "Account"

    case staked
    case stash
    case controller
    case account(_ accountId: Data)
}

extension RewardDestinationArg: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.stakedField:
            self = .staked
        case Self.stashField:
            self = .stash
        case Self.controllerField:
            self = .controller
        case Self.accountField:
            let data = try container.decode(Data.self)
            self = .account(data)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .staked:
            try container.encode(Self.stakedField)
            try container.encodeNil()
        case .stash:
            try container.encode(Self.stashField)
            try container.encodeNil()
        case .controller:
            try container.encode(Self.controllerField)
            try container.encodeNil()
        case let .account(data):
            try container.encode(Self.accountField)
            try container.encode(data)
        }
    }
}
