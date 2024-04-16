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

    private lazy var walletAssetsObserverQueue: DispatchQueue = {
        DispatchQueue(label: "co.jp.soramitsu.asset.observer.deliveryQueue")
    }()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        accountInfoRemote: AccountInfoRemoteService,
        eventCenter: EventCenterProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.accountInfoRemote = accountInfoRemote
        self.eventCenter = eventCenter
    }

    // MARK: - WalletAssetsObserver

    func update(wallet: MetaAccountModel) {
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
        chainRegistry.chainsUnsubscribe(self)
    }

    // MARK: - Private methods

    private func handleChains(changes: [DataProviderChange<ChainModel>]) {
        Task {
            let result = try await withThrowingTaskGroup(
                of: (ChainModel, [ChainAssetId: AccountInfo?]).self,
                returning: [ChainModel: [ChainAssetId: AccountInfo?]].self,
                body: { [wallet] group in
                    changes.forEach { change in
                        switch change {
                        case let .insert(chain):
                            group.addTask {
                                let accountInfos = try await self.accountInfoRemote.fetchAccountInfos(for: chain, wallet: wallet)
                                return (chain, accountInfos)
                            }
                        case .update, .delete:
                            break
                        }
                    }

                    try await group.waitForAll()
                    var taskResults = [ChainModel: [ChainAssetId: AccountInfo?]]()
                    do {
                        for try await result in group {
                            taskResults[result.0] = result.1
                        }
                    } catch {
                        Logger.shared.error("asdfasdfasdfadsf, \(error)")
                    }
                    return taskResults
                }
            )
            updateCurrentWallet(with: result)
            performSaveAndNitify()
        }
    }

    private func performSaveAndNitify() {
//        workItem.cancel()
//        workItem = DispatchWorkItem(block: { [weak self] in
        SelectedWalletSettings.shared.performSave(value: wallet) { [weak self] _ in
            guard let self else {
                return
            }
            let event = MetaAccountModelChangedEvent(account: self.wallet)
            self.eventCenter.notify(with: event)
        }
//        })
//        walletAssetsObserverQueue.asyncAfter(deadline: .now() + 1, execute: workItem)
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
                let isDefaultVisibleChainAsset = chainAsset.chain.rank != nil && chainAsset.asset.isUtility
                if let accountInfo = value, accountInfo.zero() {
                    isHidden = !isDefaultVisibleChainAsset
                } else {
                    isHidden = !isDefaultVisibleChainAsset
                }

                let assetVisibility = AssetVisibility(assetId: chainAsset.identifier, hidden: isHidden)
                let updatedWallet = update(wallet, with: assetVisibility)
                wallet = updatedWallet
            }
        }
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
