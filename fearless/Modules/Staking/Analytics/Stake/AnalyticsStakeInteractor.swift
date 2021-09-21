import RobinHood
import BigInt

final class AnalyticsStakeInteractor {
    weak var presenter: AnalyticsStakeInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let operationManager: OperationManagerProtocol
    private let assetId: WalletAssetId
    private let chain: Chain
    private let selectedAccountAddress: AccountAddress

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        selectedAccountAddress: AccountAddress,
        assetId: WalletAssetId,
        chain: Chain
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.operationManager = operationManager
        self.selectedAccountAddress = selectedAccountAddress
        self.assetId = assetId
        self.chain = chain
    }
}

extension AnalyticsStakeInteractor: AnalyticsStakeInteractorInputProtocol {
    func setup() {
        priceProvider = subscribeToPriceProvider(for: assetId)
        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)
    }

    func fetchStakeHistory(stashAddress: AccountAddress) {
        guard let analyticsURL = chain.analyticsURL else { return }
        let subqueryStakeHistorySource = SubqueryStakeSource(address: stashAddress, url: analyticsURL)
        let fetchOperation = subqueryStakeHistorySource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData() ?? []
                    self?.presenter.didReceieve(stakeDataResult: .success(response))
                } catch {
                    self?.presenter.didReceieve(stakeDataResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

extension AnalyticsStakeInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension AnalyticsStakeInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>) {
        presenter.didReceiveStashItem(result: result)
    }
}
