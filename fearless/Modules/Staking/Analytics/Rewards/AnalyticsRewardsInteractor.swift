import UIKit
import RobinHood

final class AnalyticsRewardsInteractor {
    weak var presenter: AnalyticsRewardsInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol

    private let analyticsService: AnalyticsService?
    private let assetId: WalletAssetId
    private let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    private let selectedAccountAddress: AccountAddress
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashControllerProvider: StreamableProvider<StashItem>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        analyticsService: AnalyticsService?,
        assetId: WalletAssetId,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        selectedAccountAddress: AccountAddress
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.analyticsService = analyticsService
        self.assetId = assetId
        self.substrateProviderFactory = substrateProviderFactory
        self.selectedAccountAddress = selectedAccountAddress
    }

    private func fetchAnalyticsRewards() {
        // TODO: delete stub data
        let timestamp = Int64(Date().timeIntervalSince1970)
        let stubData = (1 ..< 100).map {
            SubqueryRewardItemData(amount: $0.description, isReward: true, timestamp: timestamp - $0 * 10000)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.presenter?.didReceieve(rewardItemData: .success(stubData))
        }
    }

    private func subscribeToStashControllerProvider() {
        let stashControllerProvider = substrateProviderFactory.createStashItemProvider(for: selectedAccountAddress)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem = changes.reduceToLastChange()
            self?.presenter.didReceiveStashItem(result: .success(stashItem))
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceiveStashItem(result: .failure(error))
            return
        }

        stashControllerProvider.addObserver(
            self,
            deliverOn: .main,
            executing: changesClosure,
            failing: failureClosure,
            options: StreamableProviderObserverOptions.substrateSource()
        )
    }
}

extension AnalyticsRewardsInteractor: AnalyticsRewardsInteractorInputProtocol {
    func setup() {
        fetchAnalyticsRewards()
        priceProvider = subscribeToPriceProvider(for: assetId)
        subscribeToStashControllerProvider()
    }
}

extension AnalyticsRewardsInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}
