import Foundation
import RobinHood
import SSFUtils
import SSFModels

final class ParachainSubqueryRewardsSource {
    typealias Model = [SubqueryRewardItemData]

    private let address: AccountAddress
    private let startTimestamp: Int64?
    private let endTimestamp: Int64?
    private let operationFactory: RewardOperationFactoryProtocol

    init(
        address: AccountAddress,
        url _: URL,
        startTimestamp: Int64? = nil,
        endTimestamp: Int64? = nil,
        operationFactory: RewardOperationFactoryProtocol
    ) {
        self.address = address
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.operationFactory = operationFactory
    }
}

extension ParachainSubqueryRewardsSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<[SubqueryRewardItemData]?> {
        let rewardOperation = operationFactory.createDelegatorRewardsOperation(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let address = self.address

        let mappingOperation = ClosureOperation<[SubqueryRewardItemData]?> {
            let rewards = try rewardOperation.extractNoCancellableResultData()
            return rewards.rewardHistory(for: address).compactMap {
                SubqueryRewardItemData(
                    rewardHistoryItem: $0,
                    stashAddress: address
                )
            }
        }

        mappingOperation.addDependency(rewardOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [rewardOperation])
    }
}
