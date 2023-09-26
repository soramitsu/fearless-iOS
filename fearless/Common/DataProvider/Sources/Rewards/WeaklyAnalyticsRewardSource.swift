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

final class RelaychainWeaklyAnalyticsRewardSource {
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

extension RelaychainWeaklyAnalyticsRewardSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryRewardItemData]?> {
        let now = Date().timeIntervalSince1970
        let sevenDaysAgo = Date().addingTimeInterval(-(.secondsInDay * 7)).timeIntervalSince1970

        let rewardOperation = operationFactory.createHistoryOperation(
            address: address,
            startTimestamp: Int64(sevenDaysAgo),
            endTimestamp: Int64(now)
        )

        let mappingOperation = ClosureOperation<[SubqueryRewardItemData]?> {
            let rewards = try rewardOperation.extractNoCancellableResultData()
            return rewards.data.compactMap { wrappedReward in
                guard
                    let reward = wrappedReward.rewardInfo,
                    let validatorAddress = reward.validator,
                    let timestamp = Int64(wrappedReward.timestamp),
                    let era = reward.era, era >= 0,
                    let amount = BigUInt(string: reward.amount) else {
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
