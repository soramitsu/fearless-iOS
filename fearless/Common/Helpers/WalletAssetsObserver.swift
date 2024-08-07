import Foundation
import RobinHood
import SSFModels
import SoraKeystore

protocol WalletAssetsObserver: ApplicationServiceProtocol {
    func update(wallet: MetaAccountModel)
//    func updateVisibility(
//        wallet: MetaAccountModel?,
//        chainAssets: [ChainAsset]
//    ) async -> MetaAccountModel
}

final class WalletAssetsObserverImpl: WalletAssetsObserver {
    private var wallet: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol
    private let eventCenter: EventCenterProtocol
    private let logger: LoggerProtocol
    private let userDefaultsStorage: SettingsManagerProtocol

    private lazy var walletAssetsObserverQueue: DispatchQueue = {
        DispatchQueue(label: "co.jp.soramitsu.asset.observer.deliveryQueue")
    }()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.eventCenter = eventCenter
        self.logger = logger
        self.userDefaultsStorage = userDefaultsStorage
    }

    // MARK: - WalletAssetsObserver

    func update(wallet: MetaAccountModel) {
        throttle()
        checkNewAccounts(for: wallet)
        self.wallet = wallet
        setup()
    }

//    func updateVisibility(
//        wallet: MetaAccountModel?,
//        chainAssets: [ChainAsset]
//    ) async -> MetaAccountModel {
//        if let wallet {
//            self.wallet = wallet
//        }
//        let chains = chainAssets
//            .map { $0.chain }
//            .uniq(predicate: { $0.chainId })
//        let updatedWallet = await updateVisibility(for: chains)
//        return updatedWallet
//    }

    // MARK: - ApplicationServiceProtocol

    func setup() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: walletAssetsObserverQueue
        ) { [weak self] changes in
            self?.handleChains(changes: changes, accounts: nil)
        }
    }

    func throttle() {
        chainRegistry.chainsUnsubscribe(self)
    }

    // MARK: - Private methods

    private func handleChains(changes: [DataProviderChange<ChainModel>], accounts _: [ChainAccountModel]?) {
        Task {
            let chains = changes.filter {
                switch $0 {
                case .insert, .update:
                    return true
                default:
                    return false
                }
            }.compactMap { $0.item }

            updateCurrentWallet(with: chains)
            performSaveAndNotify()
        }
    }

    private func checkNewAccounts(for wallet: MetaAccountModel) {
        let newAccounts = wallet.chainAccounts.subtracting(self.wallet.chainAccounts)
        self.wallet = wallet
        guard newAccounts.isNotEmpty else {
            return
        }
        scanAccountInfo(for: Array(newAccounts))
    }

    private func scanAccountInfo(for accounts: [ChainAccountModel]) {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: walletAssetsObserverQueue
        ) { [weak self] changes in
            self?.handleChains(changes: changes, accounts: accounts)
        }
    }

    private func emptyAccountInfos(for chain: ChainModel) -> [ChainAssetId: AccountInfo?] {
        let mapped: [(ChainAssetId, AccountInfo?)] = chain
            .chainAssets
            .map { ($0.chainAssetId, nil) }
            .uniq(predicate: { $0.0 })
        return Dictionary(uniqueKeysWithValues: mapped)
    }

    private func performSaveAndNotify() {
        SelectedWalletSettings.shared.performSave(value: wallet) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case let .success(wallet):
                let event = MetaAccountModelChangedEvent(account: wallet)
                self.eventCenter.notify(with: event)
                self.markAsMigrated(wallet)
            case let .failure(failure):
                self.logger.customError(failure)
            }
        }
    }

    private func updateCurrentWallet(with chains: [ChainModel]) {
        let filtered = chains.filter { wallet.assetsVisibility.map { $0.identifier }.contains($0.identifier) == false }
        setDefaultVisibilitiesIfNeeded(chains: filtered)
    }

    private func setDefaultVisibilitiesIfNeeded(chains: [ChainModel]) {
        let isNewWallet = wallet.assetsVisibility.filter { !$0.hidden }.isEmpty
        guard isNewWallet else {
            return
        }
        let chainAssets: [ChainAsset] = chains
            .map { $0.chainAssets }
            .reduce([], +)
        let defaultVisibilities = chainAssets.map {
            let isHidden = !($0.chain.rank != nil && $0.asset.isUtility)
            let visibility = AssetVisibility(assetId: $0.identifier, hidden: isHidden)
            return visibility
        }
        wallet = wallet.replacingAssetsVisibility(defaultVisibilities)
    }

    private func update(
        _ wallet: MetaAccountModel,
        with assetVisibility: AssetVisibility
    ) -> MetaAccountModel {
        var assetVivibilities = wallet.assetsVisibility.filter { $0.assetId != assetVisibility.assetId }
        assetVivibilities.append(assetVisibility)
        let updatedWallet = wallet.replacingAssetsVisibility(assetVivibilities)
        return updatedWallet
    }

    private func markAsMigrated(_ wallet: MetaAccountModel) {
        let isFirstRunKey = createKeyForMigrated(wallet: wallet)
        userDefaultsStorage.set(value: true, for: isFirstRunKey)
    }

    private func createKeyForMigrated(
        wallet: MetaAccountModel
    ) -> String {
        [
            "asset.management.should.migrate.wallet",
            wallet.metaId
        ].joined(separator: ":")
    }
}
