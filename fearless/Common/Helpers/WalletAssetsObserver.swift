import Foundation
import RobinHood
import SSFModels

protocol WalletAssetsObserver: ApplicationServiceProtocol {
    func update(wallet: MetaAccountModel)
}

final class WalletAssetsObserverImpl: WalletAssetsObserver {
    private var wallet: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol
    private let eventCenter: EventCenterProtocol
    private let accountInfoRemote: AccountInfoRemoteService
    private let logger: LoggerProtocol

    private lazy var walletAssetsObserverQueue: DispatchQueue = {
        DispatchQueue(label: "co.jp.soramitsu.asset.observer.deliveryQueue")
    }()

    private var currentTask: Task<Void, Error>?

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        accountInfoRemote: AccountInfoRemoteService,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.accountInfoRemote = accountInfoRemote
        self.eventCenter = eventCenter
        self.logger = logger
    }

    // MARK: - WalletAssetsObserver

    func update(wallet: MetaAccountModel) {
        currentTask?.cancel()
        self.wallet = wallet
        throttle()
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
            self?.handleChains(changes: changes)
        }
    }

    func throttle() {
        currentTask?.cancel()
        chainRegistry.chainsUnsubscribe(self)
    }

    // MARK: - Private methods

    private func handleChains(changes: [DataProviderChange<ChainModel>]) {
        currentTask = Task {
            let result = await withTaskGroup(
                of: (ChainModel, [ChainAssetId: AccountInfo?]).self,
                returning: [ChainModel: [ChainAssetId: AccountInfo?]].self,
                body: { [wallet] group in
                    changes.forEach { change in
                        switch change {
                        case let .insert(chain):
                            group.addTask {
                                do {
                                    let accountInfos = try await self.accountInfoRemote.fetchAccountInfos(for: chain, wallet: wallet)
                                    return (chain, accountInfos)
                                } catch {
                                    self.logger.customError(error)
                                    let empty = self.emptyAccountInfos(for: chain)
                                    return (chain, empty)
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
            performSaveAndNitify()
        }
    }

    private func emptyAccountInfos(for chain: ChainModel) -> [ChainAssetId: AccountInfo?] {
        Dictionary(uniqueKeysWithValues: chain.chainAssets.map { ($0.chainAssetId, nil) })
    }

    private func performSaveAndNitify() {
        SelectedWalletSettings.shared.performSave(value: wallet) { [weak self] _ in
            guard let self else {
                return
            }
            let event = MetaAccountModelChangedEvent(account: self.wallet)
            self.eventCenter.notify(with: event)
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
                    isHidden = accountInfo.zero()
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
}