import RobinHood
import BigInt

final class AnalyticsRewardsInteractor {
    weak var presenter: AnalyticsRewardsInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol

    let operationManager: OperationManagerProtocol
    private let analyticsService: AnalyticsService?
    private let assetId: WalletAssetId
    private let selectedAccountAddress: AccountAddress
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        analyticsService: AnalyticsService?,
        assetId: WalletAssetId,
        selectedAccountAddress: AccountAddress
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.operationManager = operationManager
        self.analyticsService = analyticsService
        self.assetId = assetId
        self.selectedAccountAddress = selectedAccountAddress
    }
}

extension AnalyticsRewardsInteractor: AnalyticsRewardsInteractorInputProtocol {
    func setup() {
        priceProvider = subscribeToPriceProvider(for: assetId)
        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)
    }

    func fetchRewards(stashAddress: AccountAddress) {
        let subqueryRewardsSource = SubqueryRewardsSource(address: stashAddress, url: URL(string: "http://localhost:3000/")!)
        let fetchOperation = subqueryRewardsSource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData() ?? []
                    self?.presenter.didReceieve(rewardItemData: .success(response))
                } catch {
                    self?.presenter.didReceieve(rewardItemData: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

extension AnalyticsRewardsInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension AnalyticsRewardsInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>) {
        presenter.didReceiveStashItem(result: result)
    }
}
