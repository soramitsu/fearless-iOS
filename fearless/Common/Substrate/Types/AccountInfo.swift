import Foundation
import SSFUtils
import BigInt
import RobinHood

// MARK: - OLD

struct OldAccountInfo: Codable, Equatable {
    @StringCodable var nonce: UInt32
    @StringCodable var consumers: UInt32
    @StringCodable var providers: UInt32
    let data: OldAccountData

    init(nonce: UInt32, consumers: UInt32, providers: UInt32, data: OldAccountData) {
        self.nonce = nonce
        self.consumers = consumers
        self.providers = providers
        self.data = data
    }

    func nonZero() -> Bool {
        data.total > 0
    }

    func zero() -> Bool {
        data.total == BigUInt.zero
    }
}

struct OldAccountData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case free
        case reserved
        case frozen
        case flags
        case miscFrozen
        case feeFrozen
    }

    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var miscFrozen: BigUInt
    @StringCodable var feeFrozen: BigUInt

    init(free: BigUInt, reserved: BigUInt, miscFrozen: BigUInt, feeFrozen: BigUInt) {
        self.free = free
        self.reserved = reserved
        self.miscFrozen = miscFrozen
        self.feeFrozen = feeFrozen
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(free, forKey: .free)
        try container.encode(reserved, forKey: .reserved)
        try container.encode(feeFrozen, forKey: .feeFrozen)
        try container.encode(miscFrozen, forKey: .miscFrozen)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        free = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .free).value
        reserved = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .reserved).value
        feeFrozen = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .feeFrozen).value
        miscFrozen = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .miscFrozen).value
    }
}

extension OldAccountData {
    var total: BigUInt { free + reserved }
    var locked: BigUInt { miscFrozen + feeFrozen }
    var stakingAvailable: BigUInt { free - miscFrozen }
    var sendAvailable: BigUInt { free - miscFrozen }
}

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
            frozen: ormlAccountInfo.frozen,
            flags: .zero
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
            frozen: BigUInt.zero,
            flags: BigUInt.zero
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
    enum CodingKeys: String, CodingKey {
        case free
        case reserved
        case frozen
        case flags
        case miscFrozen
        case feeFrozen
    }

    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var frozen: BigUInt
    @StringCodable var flags: BigUInt

    init(free: BigUInt, reserved: BigUInt, frozen: BigUInt, flags: BigUInt? = .zero) {
        self.free = free
        self.reserved = reserved
        self.frozen = frozen
        self.flags = flags ?? .zero
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(free, forKey: .free)
        try container.encode(reserved, forKey: .reserved)
        try container.encode(frozen, forKey: .frozen)
        try container.encode(flags, forKey: .flags)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        free = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .free).value
        reserved = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .reserved).value
        do {
            flags = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .flags).value
        } catch {
            flags = .zero
        }

        do {
            frozen = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .frozen).value
        } catch {
            let feeFrozen = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .feeFrozen).value
            let miscFrozen = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .miscFrozen).value

            frozen = max(feeFrozen, miscFrozen)
        }
    }
}

extension AccountData {
    var total: BigUInt { free + reserved }
    var locked: BigUInt { frozen }
    var stakingAvailable: BigUInt { free - frozen }
    var sendAvailable: BigUInt { free - frozen }
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
