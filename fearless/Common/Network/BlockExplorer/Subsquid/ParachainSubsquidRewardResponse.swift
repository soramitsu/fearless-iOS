import Foundation
import BigInt

struct SubsquidDelegatorRewardsData: Decodable {
    let historyElements: [SubsquidDelegatorRewardItem]
}

struct SubsquidDelegatorReward: Decodable {
    enum CodingKeys: String, CodingKey {
        case amount
        case era
        case stash
        case validator
    }

    let amount: BigUInt
    let era: Int?
    let stash: String?
    let validator: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let amountString = try container.decode(String.self, forKey: .amount)

        guard let decodedAmount = RewardAmountParser.parse(amountString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .amount,
                in: container,
                debugDescription: "Reward amount must be an unsigned integer string"
            )
        }

        amount = decodedAmount
        era = try? container.decode(Int.self, forKey: .era)
        stash = try? container.decode(String.self, forKey: .stash)
        validator = try? container.decode(String.self, forKey: .validator)
    }
}

struct SubsquidDelegatorRewardItem: Decodable, RewardHistoryItemProtocol {
    enum CodingKeys: String, CodingKey {
        case id
        case address
        case timestamp
        case blockNumber = "blockHeight"
        case reward
    }

    let id: String
    let address: String?
    let timestamp: Int64
    let blockNumber: Int
    let reward: SubsquidDelegatorReward

    var type: SubqueryDelegationAction { .reward }
    var timestampInSeconds: String { String(timestamp) }
    var amount: BigUInt { reward.amount }
    var attribution: RewardHistoryAttribution? {
        let era = reward.era.flatMap { value in
            value >= 0 ? UInt64(value) : nil
        }
        return RewardHistoryAttribution(
            validatorAddress: reward.validator,
            era: era
        )
    }
}

extension SubsquidDelegatorRewardsData: RewardHistoryResponseProtocol {
    func rewardHistory(for address: String) -> [RewardHistoryItemProtocol] {
        historyElements.filter { item in
            item.address == address && item.reward.stash == address
        }
    }
}
