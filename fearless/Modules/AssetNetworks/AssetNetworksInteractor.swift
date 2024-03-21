import UIKit
import SSFModels

final class AssetNetworksInteractor {
    // MARK: - Private properties

    private weak var output: AssetNetworksInteractorOutput?
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter

    private let chainAsset: ChainAsset
    private let chainAssetFetching: ChainAssetFetchingProtocol

    private var availableChainAssets: [ChainAsset] = []

    init(
        chainAsset: ChainAsset,
        chainAssetFetching: ChainAssetFetchingProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter
    ) {
        self.chainAsset = chainAsset
        self.chainAssetFetching = chainAssetFetching
        self.priceLocalSubscriber = priceLocalSubscriber
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
            filters: [.assetNames([chainAsset.asset.symbol, "xc\(chainAsset.asset.symbol)"])],
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
        pricesProvider = try? priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
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

extension AssetNetworksInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePricesData(result: result)
    }
}
