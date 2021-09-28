import Foundation
import RobinHood

class StakingAccountUpdatingService {
    let accountResolver: StakingAccountResolver
    let accountSubscription: StakingAccountSubscription

    init(
        accountId: AccountId,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat,
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        let stashItemRepository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createStashItemRepository()

        accountResolver = StakingAccountResolver(
            accountId: accountId,
            chainId: chainId,
            chainFormat: chainFormat,
            chainRegistry: chainRegistry,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: operationQueue,
            repository: stashItemRepository
        )

        accountSubscription = StakingAccountSubscription(
            accountId: accountId,
            chainId: chainId,
            chainFormat: chainFormat,
            chainRegistry: chainRegistry,
            provider: <#T##StreamableProvider<StashItem>#>, childSubscriptionFactory: <#T##ChildSubscriptionFactoryProtocol#>, operationQueue: <#T##OperationQueue#>)
    }
}
