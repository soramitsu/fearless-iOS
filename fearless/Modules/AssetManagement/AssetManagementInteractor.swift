import UIKit
import SSFModels
import RobinHood

protocol AssetManagementInteractorOutput: AnyObject {
    func didReceiveUpdated(wallet: MetaAccountModel)
    func didChangeSelectedWallet()
}

actor AssetManagementInteractor {
    // MARK: - Private properties

    private weak var output: AssetManagementInteractorOutput?

    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoFetchingProvider: AccountInfoFetchingProtocol
    private let eventCenter: EventCenterProtocol
    private let accountInfoRemoteService: AccountInfoRemoteService
    private let selectedWalletSettings: PersistentValueSettings<MetaAccountModel>
    private nonisolated let selectionScope = PortfolioCallbackScope()
    private let selectionRequest: UUID

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoFetchingProvider: AccountInfoFetchingProtocol,
        eventCenter: EventCenterProtocol,
        accountInfoRemoteService: AccountInfoRemoteService,
        selectedWalletSettings: PersistentValueSettings<MetaAccountModel> = SelectedWalletSettings.shared
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.eventCenter = eventCenter
        self.accountInfoRemoteService = accountInfoRemoteService
        self.selectedWalletSettings = selectedWalletSettings
        selectionRequest = selectionScope.snapshot()

        self.eventCenter.add(observer: self)
    }

    private func updateVisibility(
        wallet: MetaAccountModel,
        assetId: String,
        chainAsset: ChainAsset? = nil,
        hidden: Bool
    ) async -> MetaAccountModel {
        guard selectionScope.isCurrent(selectionRequest) else { return wallet }
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

    func changeGroup(hidden: Bool, chainAssets: [ChainAsset], wallet: MetaAccountModel) async {
        var seen = Set<AssetKey>()
        for asset in chainAssets where seen.insert(asset.assetKey).inserted {
            guard selectionScope.isCurrent(selectionRequest) else { return }
            _ = await updateVisibility(wallet: wallet, assetId: asset.identifier, chainAsset: asset, hidden: hidden)
        }
    }

    func resetToAutomatic(chainAsset: ChainAsset, wallet: MetaAccountModel) async {
        guard selectionScope.isCurrent(selectionRequest) else { return }
        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: chainAsset.assetKey)
        eventCenter.notify(with: AssetVisibilityPreferenceChangedEvent(walletId: wallet.metaId, assetKey: chainAsset.assetKey, preference: .auto))
    }

    func resetOrder(wallet: MetaAccountModel) async throws -> MetaAccountModel {
        guard selectionScope.isCurrent(selectionRequest), wallet.assetKeysOrder != nil else { throw CancellationError() }
        let scope = selectionScope, request = selectionRequest
        let saved: MetaAccountModel = try await withCheckedThrowingContinuation { continuation in
            let accepted = selectedWalletSettings.save(
                value: wallet.replacingAssetKeysOrder(nil),
                ifCurrentValueSatisfies: { $0 == wallet && scope.isCurrent(request) },
                runningCompletionIn: nil,
                completionClosure: { continuation.resume(with: $0) }
            )
            if !accepted { continuation.resume(throwing: CancellationError()) }
        }
        guard selectionScope.isCurrent(selectionRequest), selectedWalletSettings.value == saved else { throw CancellationError() }
        eventCenter.notify(with: MetaAccountModelChangedEvent(account: saved))
        return saved
    }

    func setup(with output: AssetManagementInteractorOutput) async {
        self.output = output
        if !selectionScope.isCurrent(selectionRequest) { output.didChangeSelectedWallet() }
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

    /// Refresh only balance evidence. It must never manufacture a user preference
    /// or save a wallet snapshot merely because discovery found a zero balance.
    func refreshAccountInfos(
        for chainAssets: [ChainAsset], wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        var result: [ChainAssetKey: AccountInfo?] = [:]
        var seen = Set<AssetKey>()
        let eligible = chainAssets.filter {
            !$0.chain.disabled && !(wallet.unusedChainIds ?? []).contains($0.chain.chainId) &&
                wallet.fetch(for: $0.chain.accountRequest()) != nil && seen.insert($0.assetKey).inserted
        }
        var firstFailure: Error?
        var successfulNetworks = 0
        for (_, assets) in Dictionary(grouping: eligible, by: { $0.chain.chainId }).sorted(by: { $0.key < $1.key }) {
            try Task.checkCancellation()
            guard selectionScope.isCurrent(selectionRequest) else { throw CancellationError() }
            guard let chain = assets.first?.chain, let account = wallet.fetch(for: chain.accountRequest()) else { continue }
            NetworkScanStateStore.markAttempt(for: chain, walletId: wallet.metaId)
            do {
                let infos = try await accountInfoRemoteService.fetchAccountInfos(for: chain, wallet: wallet)
                guard selectionScope.isCurrent(selectionRequest) else { throw CancellationError() }
                successfulNetworks += 1
                NetworkScanStateStore.markSuccess(for: chain, walletId: wallet.metaId)
                for asset in assets {
                    if let info = infos[asset.chainAssetId] { result[asset.uniqueKey(accountId: account.accountId)] = .some(info) }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                firstFailure = firstFailure ?? error
                NetworkScanStateStore.markFailure(for: chain, walletId: wallet.metaId)
            }
        }
        if successfulNetworks == 0, let firstFailure { throw firstFailure }
        return result
    }
}

// MARK: - EventVisitorProtocol

extension AssetManagementInteractor: EventVisitorProtocol {
    nonisolated func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        selectionScope.invalidate()
        Task { await output?.didChangeSelectedWallet() }
    }

    nonisolated func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        Task {
            await output?.didReceiveUpdated(wallet: event.account)
        }
    }
}
