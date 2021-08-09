import RobinHood
import BigInt

final class AnalyticsRewardsInteractor {
    weak var presenter: AnalyticsRewardsInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol

    private let analyticsService: AnalyticsService?
    private let assetId: WalletAssetId
    private let selectedAccountAddress: AccountAddress
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        analyticsService: AnalyticsService?,
        assetId: WalletAssetId,
        selectedAccountAddress: AccountAddress
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.analyticsService = analyticsService
        self.assetId = assetId
        self.selectedAccountAddress = selectedAccountAddress
    }

    private func fetchAnalyticsRewards() {
        // TODO: delete stub data
        let timestamp = Int64(Date().timeIntervalSince1970)
        let stubData = (1 ..< 100).map {
            SubqueryRewardItemData(
                amount: BigUInt(integerLiteral: UInt64($0)),
                isReward: true,
                timestamp: timestamp - $0 * 1_000_000
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            // self?.presenter?.didReceieve(rewardItemData: .success(stubData))
            self?.presenter?.didReceieve(rewardItemData: .failure(StakingPayoutConfirmError.extrinsicFailed))
        }
    }
}

extension AnalyticsRewardsInteractor: AnalyticsRewardsInteractorInputProtocol {
    func setup() {
        fetchAnalyticsRewards()
        priceProvider = subscribeToPriceProvider(for: assetId)
        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)
    }
}

extension AnalyticsRewardsInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension AnalyticsRewardsInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            presenter.didReceiveStashItem(result: .success(stashItem))
        case let .failure(error):
            presenter.didReceiveStashItem(result: .failure(error))
        }
    }
}
