import UIKit
import SSFModels

final class AssetNetworksInteractor {
    // MARK: - Private properties

    private weak var output: AssetNetworksInteractorOutput?
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter

    private let chainAsset: ChainAsset
    private let chainAssetFetching: ChainAssetFetchingProtocol

    private var availableChainAssets: [ChainAsset] = []

    init(
        chainAsset: ChainAsset,
        chainAssetFetching: ChainAssetFetchingProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter
    ) {
        self.chainAsset = chainAsset
        self.chainAssetFetching = chainAssetFetching
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
    }
}

// MARK: - AssetNetworksInteractorInput

extension AssetNetworksInteractor: AssetNetworksInteractorInput {
    func setup(with output: AssetNetworksInteractorOutput) {
        self.output = output

        getAvailableChainAssets()
    }

    private func getAvailableChainAssets() {
        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [.assetName(chainAsset.asset.symbol), .ecosystem(chainAsset.defineEcosystem())],
            sortDescriptors: []
        ) { [weak self] result in
            switch result {
            case let .success(availableChainAssets):
                self?.output?.didReceiveChainAssets(availableChainAssets)
                self?.availableChainAssets = availableChainAssets
                self?.setupSubscriptions(chainAssets: availableChainAssets)
            default:
                self?.availableChainAssets = []
            }
        }
    }

    private func setupSubscriptions(chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
        pricesProvider = subscribeToPrices(for: chainAssets)
    }
}

extension AssetNetworksInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension AssetNetworksInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePricesData(result: result)
    }
}
