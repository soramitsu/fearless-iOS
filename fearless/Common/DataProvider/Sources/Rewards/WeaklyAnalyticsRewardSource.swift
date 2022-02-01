import Foundation
import RobinHood
import FearlessUtils
import BigInt

final class WeaklyAnalyticsRewardSource {
    typealias Model = [SubqueryRewardItemData]

    let address: AccountAddress
    let operationFactory: SubqueryRewardOperationFactoryProtocol

    init(
        address: AccountAddress,
        operationFactory: SubqueryRewardOperationFactoryProtocol
    ) {
        self.address = address
        self.operationFactory = operationFactory
    }
}

extension WeaklyAnalyticsRewardSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryRewardItemData]?> {
        let now = Date().timeIntervalSince1970
        let sevenDaysAgo = Date().addingTimeInterval(-(.secondsInDay * 7)).timeIntervalSince1970

        let rewardOperation = operationFactory.createOperation(
            address: address,
            startTimestamp: Int64(sevenDaysAgo),
            endTimestamp: Int64(now)
        )

        let mappingOperation = ClosureOperation<[SubqueryRewardItemData]?> {
            let rewards = try rewardOperation.extractNoCancellableResultData()
            return rewards.historyElements.nodes.compactMap { wrappedReward in
                guard
                    let reward = wrappedReward.reward,
                    let validatorAddress = reward.validator,
                    let timestamp = Int64(wrappedReward.timestamp),
                    let era = reward.era, era >= 0,
                    let amount = BigUInt(reward.amount) else {
                    return nil
                }

                return SubqueryRewardItemData(
                    eventId: wrappedReward.identifier,
                    timestamp: timestamp,
                    validatorAddress: validatorAddress,
                    era: EraIndex(era),
                    stashAddress: wrappedReward.address,
                    amount: amount,
                    isReward: reward.isReward
                )
            }
        }

        mappingOperation.addDependency(rewardOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [rewardOperation])
    }
}
