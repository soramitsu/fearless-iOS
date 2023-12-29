import Foundation
import RobinHood
import SSFModels

protocol AnalyticsRewardsRelaychainStrategyOutput: AnyObject {
    func didReceieveSubqueryData(_ subqueryData: [SubqueryRewardItemData]?)
    func didReceiveStashItem(_ stashItem: StashItem?)
    func didReceiveError(_ error: Error)
}

final class AnalyticsRewardsRelaychainStrategy {
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol

    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private weak var output: AnalyticsRewardsRelaychainStrategyOutput?

    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        output: AnalyticsRewardsRelaychainStrategyOutput?
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.operationManager = operationManager
        self.logger = logger
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.output = output
    }
}

extension AnalyticsRewardsRelaychainStrategy: AnalyticsRewardsStrategy {
    func setup() {
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }
    }

    func fetchRewards(address: AccountAddress) {
        guard let analyticsURL = chainAsset.chain.externalApi?.staking?.url else { return }
        let rewardOperationFactory = RewardOperationFactory.factory(
            chain: chainAsset.chain
        )
        let subqueryRewardsSource = ParachainSubqueryRewardsSource(
            address: address,
            url: analyticsURL,
            operationFactory: rewardOperationFactory
        )
        let fetchOperation = subqueryRewardsSource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceieveSubqueryData(response)
                } catch {
                    self?.output?.didReceiveError(error)
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

extension AnalyticsRewardsRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        switch result {
        case let .success(stashItem):
            if let stashAddress = stashItem?.stash {
                fetchRewards(address: stashAddress)
            }

            output?.didReceiveStashItem(stashItem)
        case let .failure(error):
            output?.didReceiveError(error)
        }
    }
}
