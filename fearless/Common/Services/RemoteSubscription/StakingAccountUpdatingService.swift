import Foundation
import RobinHood

protocol StakingAccountUpdatingServiceProtocol {
    func setupSubscription(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        chainFormat: ChainFormat,
        stakingType: StakingType
    ) throws

    func clearSubscription()
}

final class StakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol {
    private var accountResolver: StakingAccountResolver?
    private var accountSubscription: StakingAccountSubscription?

    private let chainRegistry: ChainRegistryProtocol
    private let substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol
    private let substrateDataProviderFactory: SubstrateDataProviderFactoryProtocol
    private let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol?

    init(
        chainRegistry: ChainRegistryProtocol,
        substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol,
        substrateDataProviderFactory: SubstrateDataProviderFactoryProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.chainRegistry = chainRegistry
        self.substrateRepositoryFactory = substrateRepositoryFactory
        self.substrateDataProviderFactory = substrateDataProviderFactory
        self.childSubscriptionFactory = childSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func setupSubscription(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        chainFormat: ChainFormat,
        stakingType: StakingType
    ) throws {
        let stashItemRepository = substrateRepositoryFactory.createStashItemRepository()

        let address = try accountId.toAddress(using: chainFormat)
        let stashItemProvider = substrateDataProviderFactory.createStashItemProvider(for: address)

        accountResolver = StakingAccountResolver(
            accountId: accountId,
            chainAsset: chainAsset,
            chainFormat: chainFormat,
            chainRegistry: chainRegistry,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: operationQueue,
            repository: stashItemRepository,
            logger: logger
        )

        accountSubscription = StakingAccountSubscription(
            accountId: accountId,
            chainAsset: chainAsset,
            chainFormat: chainFormat,
            chainRegistry: chainRegistry,
            provider: stashItemProvider,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: operationQueue,
            logger: logger,
            stakingType: stakingType
        )
    }

    func clearSubscription() {
        accountResolver = nil
        accountSubscription = nil
    }
}
