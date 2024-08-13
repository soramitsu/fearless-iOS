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

    private var bufferWallet: MetaAccountModel?

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

    func updatedVisibility(for chainAssets: [ChainAsset]) async -> MetaAccountModel {
        let updatedWallet = await walletAssetObserver.updateVisibility(wallet: bufferWallet, chainAssets: chainAssets)
        bufferWallet = updatedWallet
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
