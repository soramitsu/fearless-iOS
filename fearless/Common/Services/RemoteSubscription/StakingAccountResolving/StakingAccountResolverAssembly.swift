import Foundation
import RobinHood
import SSFModels

enum StakingAccountResolverAssembly {
    static func createResolver(
        accountId: AccountId,
        chainAsset: ChainAsset,
        chainFormat: ChainFormat,
        chainRegistry: ChainRegistryProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<StashItem>,
        logger: LoggerProtocol? = nil
    ) -> StakingAccountResolver {
        switch chainAsset.chain.stakingSettings?.type {
        case .reef:
            return StakingAccountResolverV13(
                accountId: accountId,
                chainAsset: chainAsset,
                chainFormat: chainFormat,
                chainRegistry: chainRegistry,
                childSubscriptionFactory: childSubscriptionFactory,
                operationQueue: operationQueue,
                repository: repository,
                logger: logger
            )
        default:
            return StakingAccountResolverV14(
                accountId: accountId,
                chainAsset: chainAsset,
                chainFormat: chainFormat,
                chainRegistry: chainRegistry,
                childSubscriptionFactory: childSubscriptionFactory,
                operationQueue: operationQueue,
                repository: repository,
                logger: logger
            )
        }
    }
}
