import UIKit
import RobinHood
import SoraKeystore
import SSFModels
import Web3
import Web3ContractABI

final class ChainAssetListInteractor {
    // MARK: - Private properties

    enum Constants {
        static let remoteFetchTimerTimeInterval: TimeInterval = 30
    }

    private weak var output: ChainAssetListInteractorOutput?

    private let assetRepository: AnyDataProviderRepository<AssetModel>
    private let operationQueue: OperationQueue
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private let eventCenter: EventCenter
    private var wallet: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let accountInfoFetchingProvider: AccountInfoFetching
    private let dependencyContainer: ChainAssetListDependencyContainer
    private let ethRemoteBalanceFetching: EthereumRemoteBalanceFetching
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private var chainAssets: [ChainAsset]?
    private var filters: [ChainAssetsFetching.Filter] = []
    private var sorts: [ChainAssetsFetching.SortDescriptor] = []
    private let priceLocalSubscriber: PriceLocalStorageSubscriber

    private let mutex = NSLock()
    private var remoteFetchTimer: Timer?

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    weak var presenter: ChainAssetListInteractorOutput?

    init(
        wallet: MetaAccountModel,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        assetRepository: AnyDataProviderRepository<AssetModel>,
        operationQueue: OperationQueue,
        eventCenter: EventCenter,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        accountInfoFetchingProvider: AccountInfoFetching,
        dependencyContainer: ChainAssetListDependencyContainer,
        ethRemoteBalanceFetching: EthereumRemoteBalanceFetching,
        chainAssetFetching: ChainAssetFetchingProtocol
    ) {
        self.wallet = wallet
        self.priceLocalSubscriber = priceLocalSubscriber
        self.assetRepository = assetRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.accountRepository = accountRepository
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.dependencyContainer = dependencyContainer
        self.ethRemoteBalanceFetching = ethRemoteBalanceFetching
        self.chainAssetFetching = chainAssetFetching
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
                case .success:
                    guard shouldNotify else { return }
                    self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: updatedAccount))
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
        sorts: [ChainAssetsFetching.SortDescriptor],
        useCashe: Bool
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        self.filters = filters
        self.sorts = sorts

        let chainAssetFetching = dependencyContainer.buildDependencies(for: wallet).chainAssetFetching
        chainAssetFetching.fetch(
            shouldUseCache: useCashe,
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

                self?.accountInfoFetchingProvider.fetch(for: chainAssets, wallet: strongSelf.wallet) { accountInfosByChainAssets in
                    self?.ethRemoteBalanceFetching.fetch(for: chainAssets, wallet: strongSelf.wallet) { _ in }
                    self?.output?.didReceive(accountInfosByChainAssets: accountInfosByChainAssets)
                    self?.subscribeToAccountInfo(for: chainAssets)
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
        save(updatedAccount, shouldNotify: true)
    }

    func reload() {
        guard let chainAssets = chainAssets else {
            return
        }
        output?.didReceiveChainAssets(result: .success(chainAssets))
        output?.didReceive(accountInfosByChainAssets: [:])

        accountInfoFetchingProvider.fetch(for: chainAssets, wallet: wallet) { [weak self] accountInfosByChainAssets in
            self?.output?.didReceive(accountInfosByChainAssets: accountInfosByChainAssets)
            self?.subscribeToAccountInfo(for: chainAssets)
        }

        subscribeToPrice(for: chainAssets)
        guard remoteFetchTimer == nil else {
            return
        }

        remoteFetchTimer = Timer.scheduledTimer(withTimeInterval: Constants.remoteFetchTimerTimeInterval, repeats: false, block: { [weak self] timer in
            timer.invalidate()
            self?.remoteFetchTimer = nil
        })

        ethRemoteBalanceFetching.fetch(for: chainAssets, wallet: wallet) { _ in }
    }

    func getAvailableChainAssets(chainAsset: ChainAsset, completion: @escaping (([ChainAsset]) -> Void)) {
        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [.assetNames([chainAsset.asset.symbol, "xc\(chainAsset.asset.symbol)"])],
            sortDescriptors: []
        ) { result in
            switch result {
            case let .success(availableChainAssets):
                completion(availableChainAssets)
            default:
                completion([])
            }
        }
    }
}

private extension ChainAssetListInteractor {
    func subscribeToPrice(for chainAssets: [ChainAsset]) {
        guard chainAssets.isNotEmpty else {
            output?.didReceivePricesData(result: .success([]))
            return
        }
        pricesProvider = try? priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
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

extension ChainAssetListInteractor: PriceLocalSubscriptionHandler {
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
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        guard let selectedAccountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId, selectedAccountId == accountId else {
            return
        }

        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension ChainAssetListInteractor: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        output?.didReceiveWallet(wallet: event.account)

        if wallet.selectedCurrency != event.account.selectedCurrency {
            guard let chainAssets = chainAssets else {
                return
            }
            subscribeToPrice(for: chainAssets)
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

    func processZeroBalancesSettingChanged() {
        updateChainAssets(using: filters, sorts: sorts, useCashe: true)
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
        reload()
    }

    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
        updateChainAssets(using: filters, sorts: sorts, useCashe: false)
    }
}

extension ChainAssetListInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        output?.didReceiveChainsWithIssues(issues)
    }
}
