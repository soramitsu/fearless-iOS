import Foundation
import RobinHood
import SSFUtils
import BigInt

final class ParachainWeaklyAnalyticsRewardSource {
    typealias Model = [SubqueryRewardItemData]

    private let address: AccountAddress
    private let operationFactory: RewardOperationFactoryProtocol

    init(
        address: AccountAddress,
        operationFactory: RewardOperationFactoryProtocol
    ) {
        self.address = address
        self.operationFactory = operationFactory
    }
}

extension ParachainWeaklyAnalyticsRewardSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryRewardItemData]?> {
        let now = Date().timeIntervalSince1970
        let sevenDaysAgo = Date().addingTimeInterval(-(.secondsInDay * 7)).timeIntervalSince1970

        let rewardOperation = operationFactory.createDelegatorRewardsOperation(
            address: address,
            startTimestamp: Int64(sevenDaysAgo),
            endTimestamp: Int64(now)
        )

        let address = self.address

        let mappingOperation = ClosureOperation<[SubqueryRewardItemData]?> {
            let rewards = try rewardOperation.extractNoCancellableResultData()
            return rewards.rewardHistory(for: address).compactMap { wrappedReward in
                guard
                    let timestamp = Int64(wrappedReward.timestampInSeconds)
                else {
                    return nil
                }
                return SubqueryRewardItemData(
                    eventId: wrappedReward.id,
                    timestamp: timestamp,
                    validatorAddress: "",
                    era: EraIndex(0),
                    stashAddress: address,
                    amount: wrappedReward.amount,
                    isReward: wrappedReward.type == .reward
                )
            }
        }

        mappingOperation.addDependency(rewardOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [rewardOperation])
    }
}
