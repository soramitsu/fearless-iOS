import UIKit
import SSFModels
import RobinHood

protocol AssetManagementInteractorOutput: AnyObject {
    func didReceiveUpdated(wallet: MetaAccountModel)
}

actor AssetManagementInteractor {
    // MARK: - Private properties

    private weak var output: AssetManagementInteractorOutput?

    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoFetchingProvider: AccountInfoFetching
    private let eventCenter: EventCenterProtocol
    private let accountInfoRemoteService: AccountInfoRemoteService
    private let walletAssetObserver: WalletAssetsObserver

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoFetchingProvider: AccountInfoFetching,
        eventCenter: EventCenterProtocol,
        accountInfoRemoteService: AccountInfoRemoteService,
        walletAssetObserver: WalletAssetsObserver
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.eventCenter = eventCenter
        self.accountInfoRemoteService = accountInfoRemoteService
        self.walletAssetObserver = walletAssetObserver

        self.eventCenter.add(observer: self)
    }

    private func updateVisibility(
        wallet: MetaAccountModel,
        assetId: String,
        chainAsset: ChainAsset? = nil,
        hidden: Bool
    ) async -> MetaAccountModel {
        if let chainAsset {
            let preference: AssetPreference = hidden ? .hidden : .shown
            AssetVisibilityPreferenceStore.setExplicitlyHidden(
                hidden,
                walletId: wallet.metaId,
                chainAsset: chainAsset
            )
            eventCenter.notify(
                with: AssetVisibilityPreferenceChangedEvent(
                    walletId: wallet.metaId,
                    assetKey: chainAsset.assetKey,
                    preference: preference
                )
            )
        } else {
            AssetVisibilityPreferenceStore.setExplicitlyHidden(
                hidden,
                walletId: wallet.metaId,
                assetId: assetId
            )
        }
        // Asset presentation is persisted by canonical AssetKey. Keep the
        // released Core Data relationship untouched: continuously appending
        // legacy identifiers would make a future same-id asset inherit a user
        // choice that predates its discovery.
        return wallet
    }

    private func performSave(wallet: MetaAccountModel) {
        SelectedWalletSettings.shared.performSave(value: wallet) { [eventCenter] result in
            switch result {
            case .success:
                eventCenter.notify(with: MetaAccountModelChangedEvent(account: wallet))
            case .failure:
                break
            }
        }
    }
}

// MARK: - AssetManagementInteractorInput

extension AssetManagementInteractor: AssetManagementInteractorInput {
    func change(
        hidden: Bool,
        assetId: String,
        wallet: MetaAccountModel
    ) async -> MetaAccountModel {
        let updatedWallet = await updateVisibility(
            wallet: wallet,
            assetId: assetId,
            hidden: hidden
        )
        return updatedWallet
    }

    func change(
        hidden: Bool,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async -> MetaAccountModel {
        await updateVisibility(
            wallet: wallet,
            assetId: chainAsset.identifier,
            chainAsset: chainAsset,
            hidden: hidden
        )
    }

    func setup(with output: AssetManagementInteractorOutput) async {
        self.output = output
    }

    func getAvailableChainAssets() async throws -> [ChainAsset] {
        let chainAssets = try await chainAssetFetching.fetchAwait(
            shouldUseCache: true,
            filters: [.enabledChains],
            sortDescriptors: []
        )
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

    func updatedVisibility(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async -> MetaAccountModel {
        let updatedWallet = await walletAssetObserver.updateVisibility(wallet: wallet, chainAssets: chainAssets)
        performSave(wallet: updatedWallet)
        return updatedWallet
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
