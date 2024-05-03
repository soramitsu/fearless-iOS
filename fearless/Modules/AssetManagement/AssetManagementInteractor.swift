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
    private let accountInfoRemoteService: AccountInfoRemoteService

    private var bufferWallet: MetaAccountModel?

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        accountInfoFetchingProvider: AccountInfoFetching,
        eventCenter: EventCenterProtocol,
        accountInfoRemoteService: AccountInfoRemoteService
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.priceLocalSubscriber = priceLocalSubscriber
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.eventCenter = eventCenter
        self.accountInfoRemoteService = accountInfoRemoteService

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
    ) async -> MetaAccountModel {
        var visibilities = wallet.assetsVisibility.filter { $0.assetId != assetId }
        let assetVisibility = AssetVisibility(assetId: assetId, hidden: hidden)
        visibilities.append(assetVisibility)

        let updatedWallet = wallet.replacingAssetsVisibility(visibilities)
        bufferWallet = updatedWallet
        return updatedWallet
    }
}

// MARK: - AssetManagementInteractorInput

extension AssetManagementInteractor: AssetManagementInteractorInput {
    func change(
        hidden: Bool,
        assetId: String,
        wallet: MetaAccountModel
    ) async -> MetaAccountModel {
        let wallet = bufferWallet ?? wallet
        let updatedWallet = await updateVisibility(
            wallet: wallet,
            assetId: assetId,
            hidden: hidden
        )
        return updatedWallet
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

    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo? {
        let accountInfo = try await accountInfoRemoteService.fetchAccountInfo(
            for: chainAsset,
            wallet: wallet
        )
        return accountInfo
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
