import Foundation
import RobinHood
import SSFModels
import SoraKeystore

protocol WalletAssetsObserver: ApplicationServiceProtocol {
    func update(wallet: MetaAccountModel)
}

final class WalletAssetsObserverImpl: WalletAssetsObserver {
    private var wallet: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol
    private let eventCenter: EventCenterProtocol
    private let accountInfoRemote: AccountInfoRemoteService
    private let logger: LoggerProtocol
    private let userDefaultsStorage: SettingsManagerProtocol

    private lazy var walletAssetsObserverQueue: DispatchQueue = {
        DispatchQueue(label: "co.jp.soramitsu.asset.observer.deliveryQueue")
    }()

    private var currentTask: Task<Void, Error>?

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        accountInfoRemote: AccountInfoRemoteService,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.accountInfoRemote = accountInfoRemote
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

    // MARK: - ApplicationServiceProtocol

    func setup() {
        guard wallet.assetsVisibility.isEmpty else {
            return
        }
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: walletAssetsObserverQueue
        ) { [weak self] changes in
            self?.handleChains(changes: changes, accounts: nil)
        }
    }

    func throttle() {
        currentTask?.cancel()
        chainRegistry.chainsUnsubscribe(self)
    }

    // MARK: - Private methods

    private func handleChains(changes: [DataProviderChange<ChainModel>], accounts: [ChainAccountModel]?) {
        currentTask = Task {
            let result = await withTaskGroup(
                of: (ChainModel, [ChainAssetId: AccountInfo?]).self,
                returning: [ChainModel: [ChainAssetId: AccountInfo?]].self,
                body: { [wallet] group in
                    changes.forEach { change in
                        switch change {
                        case let .insert(chain):
                            if let accounts {
                                if accounts.contains(where: { $0.chainId == chain.chainId }) {
                                    group.addTask {
                                        await self.fetchAccountInfos(chain: chain, wallet: wallet)
                                    }
                                } else {
                                    return
                                }
                            } else {
                                group.addTask {
                                    await self.fetchAccountInfos(chain: chain, wallet: wallet)
                                }
                            }
                        case .update, .delete:
                            break
                        }
                    }

                    var taskResults = [ChainModel: [ChainAssetId: AccountInfo?]]()
                    for await result in group {
                        taskResults[result.0] = result.1
                    }
                    return taskResults
                }
            )
            guard result.isNotEmpty else {
                return
            }
            updateCurrentWallet(with: result)
            performSaveAndNotify()
        }
    }

    private func fetchAccountInfos(chain: ChainModel, wallet: MetaAccountModel) async -> (ChainModel, [ChainAssetId: AccountInfo?]) {
        do {
            let accountInfos = try await accountInfoRemote.fetchAccountInfos(for: chain, wallet: wallet)
            return (chain, accountInfos)
        } catch {
            logger.customError(error)
            let empty = emptyAccountInfos(for: chain)
            return (chain, empty)
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

    private func updateCurrentWallet(
        with resultMap: [ChainModel: [ChainAssetId: AccountInfo?]]
    ) {
        resultMap.forEach { chain, accountInfos in
            accountInfos.forEach { key, value in
                guard let chainAsset = chain.chainAssets.first(where: { $0.chainAssetId == key }) else {
                    return
                }

                var isHidden = true
                if let accountInfo = value {
                    isHidden = accountInfo.isZero()
                }

                let assetVisibility = AssetVisibility(assetId: chainAsset.identifier, hidden: isHidden)
                let updatedWallet = update(wallet, with: assetVisibility)
                wallet = updatedWallet
            }
        }
        let chains = resultMap.keys.map { $0 }
        setDefaultVisibilitiesIfNeeded(chains: chains)
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
