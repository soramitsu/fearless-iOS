import RobinHood
import BigInt

final class AnalyticsRewardsInteractor {
    weak var presenter: AnalyticsRewardsInteractorOutputProtocol!

    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationManager: OperationManagerProtocol
    private let asset: AssetModel
    private let chain: ChainModel
    private let selectedAccount: MetaAccountModel
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationManager = operationManager
        self.asset = asset
        self.chain = chain
        self.selectedAccount = selectedAccount
    }
}

extension AnalyticsRewardsInteractor: AnalyticsRewardsInteractorInputProtocol {
    func setup() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }
    }

    func fetchRewards(stashAddress: AccountAddress) {
        guard let analyticsURL = chain.externalApi?.staking?.url else { return }
        let subqueryRewardsSource = SubqueryRewardsSource(address: stashAddress, url: analyticsURL)
        let fetchOperation = subqueryRewardsSource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceieve(rewardItemData: .success(response))
                } catch {
                    self?.presenter.didReceieve(rewardItemData: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

extension AnalyticsRewardsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension AnalyticsRewardsInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        presenter.didReceiveStashItem(result: result)
    }
}
