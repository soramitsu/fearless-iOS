import Foundation
import RobinHood
import SSFModels

enum StakingAccountSubscriptionAssembly {
    static func createSubscription(
        accountId: AccountId,
        chainAsset: ChainAsset,
        chainFormat: ChainFormat,
        chainRegistry: ChainRegistryProtocol,
        provider: StreamableProvider<StashItem>,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) -> StakingAccountSubscription {
        StakingAccountSubscriptionV14(
            accountId: accountId,
            chainAsset: chainAsset,
            chainFormat: chainFormat,
            chainRegistry: chainRegistry,
            provider: provider,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
