import UIKit
import RobinHood
import SoraKeystore
import SSFModels
import Web3
import Web3ContractABI

final class ChainAssetListInteractor {
    // MARK: - Private properties

    private weak var output: ChainAssetListInteractorOutput?

    private let assetRepository: AnyDataProviderRepository<AssetModel>
    private let operationQueue: OperationQueue
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private let eventCenter: EventCenter
    private var wallet: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let accountInfoFetchingProviders: [AccountInfoFetchingProtocol]
    private let dependencyContainer: ChainAssetListDependencyContainer

    private var chainAssets: [ChainAsset]?
    private var filters: [ChainAssetsFetching.Filter] = []
    private var sorts: [ChainAssetsFetching.SortDescriptor] = []

    private let mutex = NSLock()

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    weak var presenter: ChainAssetListInteractorOutput?

    init(
        wallet: MetaAccountModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        assetRepository: AnyDataProviderRepository<AssetModel>,
        operationQueue: OperationQueue,
        eventCenter: EventCenter,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        accountInfoFetchingProviders: [AccountInfoFetchingProtocol],
        dependencyContainer: ChainAssetListDependencyContainer
    ) {
        self.wallet = wallet
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.assetRepository = assetRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.accountRepository = accountRepository
        self.accountInfoFetchingProviders = accountInfoFetchingProviders
        self.dependencyContainer = dependencyContainer
    }

    // MARK: - Private methods

    private func save(_ updatedAccount: MetaAccountModel, shouldNotify: Bool) {
        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self, shouldNotify] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    guard shouldNotify else { return }
                    self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}

// MARK: - ChainAssetListInteractorInput

extension ChainAssetListInteractor: ChainAssetListInteractorInput {
    func setup(with output: ChainAssetListInteractorOutput) {
        self.output = output

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        self.filters = filters
        self.sorts = sorts

        let chainAssetFetching = dependencyContainer.buildDependencies(for: wallet).chainAssetFetching
        chainAssetFetching.fetch(
            shouldUseCashe: true,
            filters: filters,
            sortDescriptors: sorts
        ) { [weak self] result in
            guard let strongSelf = self,
                  let result = result else {
                return
            }

            switch result {
            case let .success(chainAssets):
                self?.subscribeToPrice(for: chainAssets)

                self?.chainAssets = chainAssets
                self?.output?.didReceiveChainAssets(result: .success(chainAssets))

                var responseReceivedCounter: Int = 0
                self?.accountInfoFetchingProviders.forEach { accountInfoFetching in
                    accountInfoFetching.fetch(for: chainAssets, wallet: strongSelf.wallet) { accountInfosByChainAssets in
                        self?.output?.didReceive(accountInfosByChainAssets: accountInfosByChainAssets)

                        responseReceivedCounter += 1

                        if responseReceivedCounter == self?.accountInfoFetchingProviders.count {
                            self?.subscribeToAccountInfo(for: chainAssets)
                        }
                    }
                }

            case let .failure(error):
                self?.output?.didReceiveChainAssets(result: .failure(error))
            }
        }
    }

    func hideChainAsset(_ chainAsset: ChainAsset) {
        let accountRequest = chainAsset.chain.accountRequest()
        guard let accountId = wallet.fetch(for: accountRequest)?.accountId else {
            return
        }
        let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)

        var assetsVisibility = wallet.assetsVisibility.filter { $0.assetId != chainAssetKey }
        let assetVisibility = AssetVisibility(assetId: chainAssetKey, hidden: true)
        assetsVisibility.append(assetVisibility)

        let updatedWallet = wallet.replacingAssetsVisibility(assetsVisibility)
        save(updatedWallet, shouldNotify: true)
    }

    func showChainAsset(_ chainAsset: ChainAsset) {
        let accountRequest = chainAsset.chain.accountRequest()
        guard let accountId = wallet.fetch(for: accountRequest)?.accountId else {
            return
        }
        let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)

        var assetsVisibility = wallet.assetsVisibility.filter { $0.assetId != chainAssetKey }
        let assetVisibility = AssetVisibility(assetId: chainAssetKey, hidden: false)
        assetsVisibility.append(assetVisibility)

        let updatedWallet = wallet.replacingAssetsVisibility(assetsVisibility)
        save(updatedWallet, shouldNotify: true)
    }

    func markUnused(chain: ChainModel) {
        var unusedChainIds = wallet.unusedChainIds ?? []
        unusedChainIds.append(chain.chainId)
        let updatedAccount = wallet.replacingUnusedChainIds(unusedChainIds)

        save(updatedAccount, shouldNotify: true)
    }

    func saveHiddenSection(state: HiddenSectionState) {
        var filterOptions = wallet.assetFilterOptions
        switch state {
        case .hidden:
            filterOptions.removeAll(where: { $0 == .hiddenSectionOpen })
        case .expanded:
            filterOptions.append(.hiddenSectionOpen)
        case .empty:
            return
        }

        let updatedAccount = wallet.replacingAssetsFilterOptions(filterOptions)
        save(updatedAccount, shouldNotify: false)
    }
}

private extension ChainAssetListInteractor {
    func subscribeToPrice(for chainAssets: [ChainAsset]) {
        let pricesIds = chainAssets.compactMap(\.asset.priceId).uniq(predicate: { $0 })
        guard pricesIds.isNotEmpty else {
            output?.didReceivePricesData(result: .success([]))
            return
        }
        pricesProvider = subscribeToPrices(for: pricesIds)
    }

    func resetAccountInfoSubscription() {
        let accountInfoSubscriptionAdapter = dependencyContainer.buildDependencies(for: wallet).accountInfoSubscriptionAdapter
        accountInfoSubscriptionAdapter.reset()
        dependencyContainer.resetCache(walletId: wallet.metaId)
    }

    func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let accountInfoSubscriptionAdapter = dependencyContainer.buildDependencies(for: wallet).accountInfoSubscriptionAdapter

        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: accountInfosDeliveryQueue
        )
    }

    func updatePrices(with priceData: [PriceData]) {
        let updatedAssets = priceData.compactMap { priceData -> AssetModel? in
            let chainAsset = chainAssets?.first(where: { $0.asset.priceId == priceData.priceId })

            guard let asset = chainAsset?.asset else {
                return nil
            }
            return asset.replacingPrice(priceData)
        }

        let saveOperation = assetRepository.saveOperation {
            updatedAssets
        } _: {
            []
        }

        operationQueue.addOperation(saveOperation)
    }
}

extension ChainAssetListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            DispatchQueue.global().async {
                self.updatePrices(with: prices)
            }
        case .failure:
            break
        }

        output?.didReceivePricesData(result: result)
    }
}

extension ChainAssetListInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset: ChainAsset) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension ChainAssetListInteractor: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        output?.didReceiveWallet(wallet: event.account)

        if wallet.selectedCurrency != event.account.selectedCurrency {
            pricesProvider?.refresh()
        }

        if wallet.assetsVisibility != event.account.assetsVisibility {
            output?.updateViewModel(isInitSearchState: false)
        }

        if wallet.unusedChainIds != event.account.unusedChainIds {
            output?.updateViewModel(isInitSearchState: false)
        }

        if wallet.zeroBalanceAssetsHidden != event.account.zeroBalanceAssetsHidden {
            output?.updateViewModel(isInitSearchState: false)
        }

        wallet = event.account
    }

    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
//        updateChainAssets(using: filters, sorts: sorts)
    }

    func processZeroBalancesSettingChanged() {
        updateChainAssets(using: filters, sorts: sorts)
    }

    func processRemoteSubscriptionWasUpdated(event: WalletRemoteSubscriptionWasUpdatedEvent) {
        let accountInfoSubscriptionAdapter = dependencyContainer.buildDependencies(for: wallet).accountInfoSubscriptionAdapter
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: [event.chainAsset],
            handler: self,
            deliveryOn: accountInfosDeliveryQueue
        )
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        output?.handleWalletChanged(wallet: event.account)
        resetAccountInfoSubscription()
        wallet = event.account
        updateChainAssets(using: filters, sorts: sorts)
    }
}

extension ChainAssetListInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        output?.didReceiveChainsWithIssues(issues)
    }
}
