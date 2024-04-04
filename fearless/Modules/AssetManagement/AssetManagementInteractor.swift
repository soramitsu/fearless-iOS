import UIKit
import SSFModels
import RobinHood

protocol AssetManagementInteractorOutput: AnyObject {
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveUpdated(wallet: MetaAccountModel)
}

actor AssetManagementInteractor {
    // MARK: - Private properties

    private weak var output: AssetManagementInteractorOutput?

    private let chainAssetFetching: ChainAssetFetchingProtocol
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let accountInfoFetchingProvider: AccountInfoFetching
    private let eventCenter: EventCenterProtocol

    private var bufferWallet: MetaAccountModel?

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        accountInfoFetchingProvider: AccountInfoFetching,
        eventCenter: EventCenterProtocol
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.priceLocalSubscriber = priceLocalSubscriber
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.eventCenter = eventCenter

        self.eventCenter.add(observer: self)
    }

    deinit {
        guard let bufferWallet else {
            return
        }
        SelectedWalletSettings.shared.performSave(value: bufferWallet) { [eventCenter, bufferWallet] result in
            switch result {
            case .success:
                eventCenter.notify(with: MetaAccountModelChangedEvent(account: bufferWallet))
            case .failure:
                break
            }
        }
    }

    // MARK: - Private methods

    private func fetchPrices(for chainAssets: [ChainAsset]) {
        pricesProvider = priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
    }

    private func updateVisibility(
        wallet: MetaAccountModel,
        assetId: String,
        hidden: Bool
    ) async {
        var visibilities = wallet.assetsVisibility.filter { $0.assetId != assetId }
        let assetVisibility = AssetVisibility(assetId: assetId, hidden: hidden)
        visibilities.append(assetVisibility)

        let updatedWallet = wallet.replacingAssetsVisibility(visibilities)
        bufferWallet = updatedWallet
    }

    private func setDefaultAndUpdateVisibility(
        hidden: Bool,
        assetId: String,
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset]
    ) async {
        let defaultVisibility = chainAssets.map {
            let isVisible = $0.chain.rank != nil && $0.asset.isUtility
            let visibility = AssetVisibility(assetId: $0.asset.id, hidden: !isVisible)
            return visibility
        }
        let updatedWallet = wallet.replacingAssetsVisibility(defaultVisibility)
        await updateVisibility(wallet: updatedWallet, assetId: assetId, hidden: hidden)
    }
}

// MARK: - AssetManagementInteractorInput

extension AssetManagementInteractor: AssetManagementInteractorInput {
    func change(
        hidden: Bool,
        assetId: String,
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset]
    ) async {
        let wallet = bufferWallet ?? wallet
        if wallet.assetsVisibility.isEmpty {
            await setDefaultAndUpdateVisibility(
                hidden: hidden,
                assetId: assetId,
                wallet: wallet,
                chainAssets: chainAssets
            )
        } else {
            await updateVisibility(
                wallet: wallet,
                assetId: assetId,
                hidden: hidden
            )
        }
    }

    func setup(with output: AssetManagementInteractorOutput) async {
        self.output = output
    }

    func getAvailableChainAssets() async throws -> [ChainAsset] {
        let chainAssets = try await chainAssetFetching.fetchAwait(
            shouldUseCache: true,
            filters: [],
            sortDescriptors: []
        )
        fetchPrices(for: chainAssets)
        return chainAssets
    }

    func getAccountInfos(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        try await accountInfoFetchingProvider.fetchByUniqKey(
            for: chainAssets,
            wallet: wallet
        )
    }
}

// MARK: - PriceLocalSubscriptionHandler

extension AssetManagementInteractor: PriceLocalSubscriptionHandler {
    nonisolated func handlePrices(result: Result<[PriceData], Error>) {
        Task {
            await output?.didReceivePricesData(result: result)
        }
    }
}

// MARK: - EventVisitorProtocol

extension AssetManagementInteractor: EventVisitorProtocol {
    nonisolated func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        Task {
            await output?.didReceiveUpdated(wallet: event.account)
        }
    }
}
