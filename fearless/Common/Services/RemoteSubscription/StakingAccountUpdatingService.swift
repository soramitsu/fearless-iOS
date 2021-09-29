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
        substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol,
        substrateDataProviderFactory: SubstrateDataProviderFactoryProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger _: LoggerProtocol
    ) throws {
        let stashItemRepository = substrateRepositoryFactory.createStashItemRepository()

        let address = try accountId.toAddress(using: chainFormat)
        let stashItemProvider = substrateDataProviderFactory.createStashItemProvider(for: address)

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
            provider: stashItemProvider,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: operationQueue
        )
    }
}
