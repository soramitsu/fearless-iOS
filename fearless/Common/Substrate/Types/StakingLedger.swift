import Foundation
import SSFUtils
import BigInt

struct StakingLedger: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case stash
        case total
        case active
        case unlocking
        case claimedRewards
    }

    let stash: Data
    @StringCodable var total: BigUInt
    @StringCodable var active: BigUInt
    let unlocking: [UnlockChunk]
    let claimedRewards: [StringScaleMapper<UInt32>]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            stash = try container.decode(Data.self, forKey: .stash)
        } catch {
            let stashString = try container.decode(String.self, forKey: .stash)
            stash = Data(hex: stashString)
        }
        total = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .total).value
        active = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .active).value
        unlocking = try container.decode([UnlockChunk].self, forKey: .unlocking)
        claimedRewards = try container.decode([StringScaleMapper<UInt32>].self, forKey: .claimedRewards)
    }
}

struct UnlockChunk: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case value
        case era
    }

    @StringCodable var value: BigUInt
    @StringCodable var era: UInt32

    init(value: BigUInt, era: UInt32) {
        self.value = value
        self.era = era
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            era = try container.decode(StringScaleMapper<UInt32>.self, forKey: .era).value
            value = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .value).value
        } else {
            var container = try decoder.unkeyedContainer()
            era = try container.decode(StringScaleMapper<UInt32>.self).value
            value = try container.decode(StringScaleMapper<BigUInt>.self).value
        }
    }
}

extension StakingLedger {
    func redeemable(inEra activeEra: UInt32) -> BigUInt {
        unlocking.reduce(BigUInt(0)) { result, item in
            item.era <= activeEra ? (result + item.value) : result
        }
    }

    func unbonding(inEra activeEra: UInt32) -> BigUInt {
        unbondings(inEra: activeEra).reduce(BigUInt(0)) { result, item in
            result + item.value
        }
    }

    func unbondings(inEra activeEra: UInt32) -> [UnlockChunk] {
        unlocking.filter { $0.era > activeEra }
    }
}
