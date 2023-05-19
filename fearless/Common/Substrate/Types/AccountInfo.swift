import Foundation
import FearlessUtils
import BigInt
import RobinHood

// MARK: - Normal

struct AccountInfoStorageWrapper: StorageWrapper {
    let identifier: String
    let data: Data
}

struct AccountInfo: Codable, Equatable {
    @StringCodable var nonce: UInt32
    @StringCodable var consumers: UInt32
    @StringCodable var providers: UInt32
    let data: AccountData

    init(nonce: UInt32, consumers: UInt32, providers: UInt32, data: AccountData) {
        self.nonce = nonce
        self.consumers = consumers
        self.providers = providers
        self.data = data
    }

    init?(ormlAccountInfo: OrmlAccountInfo?) {
        guard let ormlAccountInfo = ormlAccountInfo else {
            return nil
        }
        nonce = 0
        consumers = 0
        providers = 0

        data = AccountData(
            free: ormlAccountInfo.free,
            reserved: ormlAccountInfo.reserved,
            miscFrozen: ormlAccountInfo.frozen,
            feeFrozen: BigUInt.zero
        )
    }

    init?(equilibriumFree: BigUInt?) {
        guard let equilibriumFree = equilibriumFree else {
            return nil
        }
        nonce = 0
        consumers = 0
        providers = 0

        data = AccountData(
            free: equilibriumFree,
            reserved: BigUInt.zero,
            miscFrozen: BigUInt.zero,
            feeFrozen: BigUInt.zero
        )
    }

    func nonZero() -> Bool {
        data.total > 0
    }

    func zero() -> Bool {
        data.total == BigUInt.zero
    }
}

struct AccountData: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var miscFrozen: BigUInt
    @StringCodable var feeFrozen: BigUInt
}

extension AccountData {
    var total: BigUInt { free + reserved }
    var frozen: BigUInt { reserved + locked }
    var locked: BigUInt { max(miscFrozen, feeFrozen) }
    var stakingAvailable: BigUInt { free - feeFrozen }
    var sendAvailable: BigUInt { free - locked }
}

// MARK: - Orml

struct OrmlAccountInfo: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var frozen: BigUInt
}

// MARK: - Equilibrium

struct EquilibriumAccountInfo: Decodable {
    @StringCodable var nonce: BigUInt
    @StringCodable var consumers: BigUInt
    @StringCodable var providers: BigUInt
    @StringCodable var sufficients: BigUInt
    var data: EquilibriumAccountData
}

enum EquilibriumAccountData: Decodable {
    static let v0Field = "V0"

    case v0data(info: EquilibriumV0AccountData)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.v0Field:
            let json = try container.decode(JSON.self)
            let info = try json.map(to: EquilibriumV0AccountData.self)
            self = .v0data(info: info)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected EquilibriumAccountData"
            )
        }
    }
}

struct EquilibriumV0AccountData: Decodable {
    let balance: [EqulibriumBalanceData]

    func mapBalances() -> [String: BigUInt] {
        var map = [String: BigUInt]()
        balance.forEach { balanceData in
            switch balanceData.positive {
            case let .positive(balance):
                map[balanceData.currencyId] = balance
            }
        }
        return map
    }
}

struct EqulibriumBalanceData: Decodable {
    let currencyId: String
    let positive: EquilibruimPositive

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        currencyId = try container.decode(String.self)
        positive = try container.decode(EquilibruimPositive.self)
    }
}

enum EquilibruimPositive: Decodable {
    static let positiveRaw = "Positive"

    case positive(balance: BigUInt)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.positiveRaw:
            let balance = try container.decode(StringScaleMapper<BigUInt>.self).value
            self = .positive(balance: balance)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected EquilibruimPositive"
            )
        }
    }
}
