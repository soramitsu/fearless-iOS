import Foundation
import BigInt
import SSFUtils

struct StakingPoolMember: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case poolId
        case points
        case lastRecordedRewardCounter
        case unbondingEras
    }

    let poolId: StringScaleMapper<UInt32>
    @StringCodable var points: BigUInt
    @StringCodable var lastRecordedRewardCounter: BigUInt
    let unbondingEras: [UnlockChunk]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        poolId = try container.decode(StringScaleMapper<UInt32>.self, forKey: .poolId)
        points = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .points).value
        lastRecordedRewardCounter = (try? container.decode(StringScaleMapper<BigUInt>.self, forKey: .lastRecordedRewardCounter).value) ?? BigUInt.zero
        unbondingEras = try container.decode([UnlockChunk].self, forKey: .unbondingEras)
    }
}

extension StakingPoolMember {
    func redeemable(inEra activeEra: UInt32) -> BigUInt {
        unbondingEras.reduce(BigUInt(0)) { result, item in
            item.era <= activeEra ? (result + item.value) : result
        }
    }

    func unbonding(inEra activeEra: UInt32) -> BigUInt {
        unbondings(inEra: activeEra).reduce(BigUInt(0)) { result, item in
            result + item.value
        }
    }

    func unbondings(inEra activeEra: UInt32) -> [UnlockChunk] {
        unbondingEras.filter { $0.era > activeEra }
    }
}
