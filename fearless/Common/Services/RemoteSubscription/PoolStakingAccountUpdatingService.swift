import Foundation
import RobinHood

protocol PoolStakingAccountUpdatingServiceProtocol {
    func setupSubscription(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        chainFormat: ChainFormat,
        stakingType: StakingType
    ) throws

    func clearSubscription()
}

final class PoolStakingAccountUpdatingService: PoolStakingAccountUpdatingServiceProtocol {
    private var accountResolver: StakingAccountResolver?
    private var accountSubscription: PoolStakingAccountSubscriptionProtocol?

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
        stakingType _: StakingType
    ) throws {
        accountSubscription = PoolStakingAccountSubscription(
            accountId: accountId,
            chainAsset: chainAsset,
            chainFormat: chainFormat,
            chainRegistry: chainRegistry,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: operationQueue,
            logger: logger
        )
        accountSubscription?.subscribeRemote()
    }

    func clearSubscription() {
        accountResolver = nil
        accountSubscription = nil
    }
}
