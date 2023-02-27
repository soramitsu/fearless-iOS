import Foundation

struct SubqueryRewardOrSlash: Decodable, RewardOrSlash {
    enum CodingKeys: String, CodingKey {
        case amount
        case isReward
        case era
        case validator
        case stash
        case eventIdx
        case assetId
    }

    let amount: String
    let isReward: Bool
    let era: Int?
    let validator: String?
    let stash: String?
    let eventIdx: String?
    let assetId: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        amount = try container.decode(String.self, forKey: .amount)
        isReward = try container.decode(Bool.self, forKey: .isReward)
        era = try? container.decode(Int.self, forKey: .era)
        validator = try? container.decode(String.self, forKey: .validator)
        stash = try? container.decode(String.self, forKey: .stash)
        if let eventIdxIntValue = try? container.decode(Int.self, forKey: .eventIdx) {
            eventIdx = "\(eventIdxIntValue)"
        } else {
            eventIdx = nil
        }
        assetId = try? container.decode(String.self, forKey: .assetId)
    }
}
