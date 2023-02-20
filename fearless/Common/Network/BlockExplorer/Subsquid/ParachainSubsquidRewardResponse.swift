import Foundation
import BigInt
import FearlessUtils

struct SubsquidDelegatorRewardsData: Decodable {
    var rewards: [SubsquidDelegatorRewardItem]
}

struct SubsquidDelegatorRewardItem: Decodable, RewardHistoryItemProtocol {
    @StringCodable var amount: BigUInt
    let id: String
    let accountId: String
    let timestamp: String
    let blockNumber: Int

    var type: SubqueryDelegationAction { .reward }
    var timestampInSeconds: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        let date = dateFormatter.date(from: timestamp)
        let timeInterval = date?.timeIntervalSince1970 ?? 0
        let timeIntervalIntValue = Int64(timeInterval)
        return "\(timeIntervalIntValue)"
    }
}

extension SubsquidDelegatorRewardsData: RewardHistoryResponseProtocol {
    func rewardHistory(for address: String) -> [RewardHistoryItemProtocol] {
        rewards.filter { $0.accountId == address }
    }
}
