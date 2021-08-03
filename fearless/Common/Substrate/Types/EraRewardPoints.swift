import FearlessUtils

typealias RewardPoint = UInt32

/// Reward points of an era. Used to split era total payout between validators.
struct EraRewardPoints: Decodable {
    /// Total number of points. Equals the sum of reward points for each validator.
    @StringCodable var total: RewardPoint

    /// The reward points earned by a given validator.
    let individual: [IndividualReward]
}

struct IndividualReward: Decodable {
    let accountId: Data
    let rewardPoint: RewardPoint

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        accountId = try container.decode(Data.self)

        let rewardScaled = try container.decode(StringScaleMapper<RewardPoint>.self)
        rewardPoint = rewardScaled.value
    }
}
