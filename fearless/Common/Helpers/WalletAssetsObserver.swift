import Foundation
import RobinHood
import SSFModels

protocol WalletAssetsObserver: ApplicationServiceProtocol {
    func update(wallet: MetaAccountModel)
}

final class WalletAssetsObserverImpl: WalletAssetsObserver {
    private var wallet: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let eventCenter: EventCenterProtocol

    private lazy var walletAssetsObserverQueue: DispatchQueue = {
        DispatchQueue(label: "co.jp.soramitsu.asset.observer.deliveryQueue")
    }()

    private lazy var workItem: DispatchWorkItem = {
        DispatchWorkItem(block: {})
    }()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.eventCenter = eventCenter
    }

    // MARK: - WalletAssetsObserver

    func update(wallet: MetaAccountModel) {
        self.wallet = wallet
        accountInfoSubscriptionAdapter.update(wallet: wallet)
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
            self?.handle(changes: changes)
        }
    }

    func throttle() {
        accountInfoSubscriptionAdapter.reset()
        chainRegistry.chainsUnsubscribe(self)
    }

    // MARK: - Private methods

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        let chainAssets: [ChainAsset] = changes
            .compactMap { $0.item }
            .map { $0.chainAssets }
            .reduce([], +)
        addSubscription(for: chainAssets)
    }

    private func addSubscription(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: walletAssetsObserverQueue
        )
    }

    private func performSaveAndNitify(wallet: MetaAccountModel) {
        guard self.wallet.assetsVisibility != wallet.assetsVisibility else {
            return
        }
        self.wallet = wallet
        workItem.cancel()
        workItem = DispatchWorkItem(block: { [weak self] in
            print("self?.accountInfoSubscriptionAdapter.reset()")
            SelectedWalletSettings.shared.performSave(value: wallet) { _ in
                let event = MetaAccountModelChangedEvent(account: wallet)
                self?.eventCenter.notify(with: event)
            }
        })
        walletAssetsObserverQueue.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    private func update(
        _ wallet: MetaAccountModel,
        with accountInfoResult: Result<AccountInfo?, Error>,
        chainAsset: ChainAsset
    ) -> MetaAccountModel {
        let existAssetVisibility = wallet.assetsVisibility.first(where: { $0.assetId == chainAsset.identifier })
        let accountInfo = try? accountInfoResult.get()
        let isZero = accountInfo?.zero() ?? true

        guard existAssetVisibility == nil || existAssetVisibility?.hidden != isZero else {
            return wallet
        }

        let assetVisibility = AssetVisibility(assetId: chainAsset.identifier, hidden: isZero)
        let updatedWallet = update(wallet, with: assetVisibility)
        return updatedWallet
//        guard let accountInfo = try? accountInfoResult.get() else {
//            return wallet
//        }
//        let isHidden = accountInfo.zero()
//        let assetVisibility = AssetVisibility(assetId: chainAsset.identifier, hidden: isHidden)
//        let updatedWallet = update(wallet, with: assetVisibility)
//        return updatedWallet
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

extension WalletAssetsObserverImpl: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset: SSFModels.ChainAsset) {
        let updatedWallet = update(wallet, with: result, chainAsset: chainAsset)
//        wallet = updatedWallet
        performSaveAndNitify(wallet: updatedWallet)
//        accountInfoSubscriptionAdapter.unsubscribe(chainAsset: chainAsset)
        let balance = try? result.get()?.data.total
        let debug = "\(chainAsset.debugName) balance: \(balance)"
        print("WalletAssetsObserverImpl", debug)
    }
}
