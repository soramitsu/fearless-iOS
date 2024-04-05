import UIKit
import RobinHood
import SoraKeystore
import SSFModels
import Web3
import Web3ContractABI
import SoraFoundation

final class ChainAssetListInteractor {
    // MARK: - Private properties

    enum Constants {
        static let remoteFetchTimerTimeInterval: TimeInterval = 30
        static let shouldPlayAssetManagementAnimateKey = "asset.manage.button.animation"
    }

    private weak var output: ChainAssetListInteractorOutput?

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
    private let userDefaultsStorage: SettingsManagerProtocol
    private let applicationHandler: ApplicationHandler
    private let walletAssetManagementHelper: WalletAssetManagementHelper

    private let mutex = NSLock()
    private var remoteFetchTimer: Timer?

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    weak var presenter: ChainAssetListInteractorOutput?

    init(
        wallet: MetaAccountModel,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        operationQueue: OperationQueue,
        eventCenter: EventCenter,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        accountInfoFetchingProvider: AccountInfoFetching,
        dependencyContainer: ChainAssetListDependencyContainer,
        ethRemoteBalanceFetching: EthereumRemoteBalanceFetching,
        chainAssetFetching: ChainAssetFetchingProtocol,
        userDefaultsStorage: SettingsManagerProtocol,
        applicationHandler: ApplicationHandler,
        walletAssetManagementHelper: WalletAssetManagementHelper
    ) {
        self.wallet = wallet
        self.priceLocalSubscriber = priceLocalSubscriber
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.accountRepository = accountRepository
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.dependencyContainer = dependencyContainer
        self.ethRemoteBalanceFetching = ethRemoteBalanceFetching
        self.chainAssetFetching = chainAssetFetching
        self.userDefaultsStorage = userDefaultsStorage
        self.applicationHandler = applicationHandler
        self.walletAssetManagementHelper = walletAssetManagementHelper
        self.applicationHandler.delegate = self
    }

    // MARK: - Private methods

    private func saveCurrent(_ current: MetaAccountModel, shouldNotify: Bool) {
        SelectedWalletSettings.shared.performSave(value: current) { [weak self] result in
            switch result {
            case .success:
                guard shouldNotify else { return }
                self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: current))
            case .failure:
                break
            }
        }
    }

    private func save(_ updatedWallet: MetaAccountModel) {
        let saveOperation = accountRepository.saveOperation {
            [updatedWallet]
        } _: {
            []
        }
        operationQueue.addOperation(saveOperation)
    }

    private func subscribeToPrice(for chainAssets: [ChainAsset]) {
        guard chainAssets.isNotEmpty else {
            output?.didReceivePricesData(result: .success([]))
            return
        }
        pricesProvider = priceLocalSubscriber.subscribeToPrices(for: chainAssets, listener: self)
    }

    private func resetAccountInfoSubscription() {
        let accountInfoSubscriptionAdapter = dependencyContainer.buildDependencies(for: wallet).accountInfoSubscriptionAdapter
        accountInfoSubscriptionAdapter.reset()
        dependencyContainer.resetCache(walletId: wallet.metaId)
    }

    private func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
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

    private func checkAssetVisibilityAndSave(wallet: MetaAccountModel) {
        let allIsHidden = wallet.assetsVisibility.filter { !$0.hidden }.isEmpty

        guard allIsHidden, let chainAssets else {
            save(wallet)
            return
        }

        let defaultVisibility = chainAssets.map {
            let isVisible = $0.chain.rank != nil && $0.asset.isUtility
            let visibility = AssetVisibility(assetId: $0.asset.id, hidden: !isVisible)
            return visibility
        }
        let updatedWallet = wallet.replacingAssetsVisibility(defaultVisibility)
        save(updatedWallet)
    }
}

// MARK: - ChainAssetListInteractorInput

extension ChainAssetListInteractor: ChainAssetListInteractorInput {
    var shouldRunManageAssetAnimate: Bool {
        get {
            userDefaultsStorage.bool(for: Constants.shouldPlayAssetManagementAnimateKey) == nil
        }
        set {
            guard userDefaultsStorage.bool(for: Constants.shouldPlayAssetManagementAnimateKey) == nil else {
                return
            }
            userDefaultsStorage.set(value: true, for: Constants.shouldPlayAssetManagementAnimateKey)
        }
    }

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

    func markUnused(chain: ChainModel) {
        var unusedChainIds = wallet.unusedChainIds ?? []
        unusedChainIds.append(chain.chainId)
        let updatedAccount = wallet.replacingUnusedChainIds(unusedChainIds)

        saveCurrent(updatedAccount, shouldNotify: true)
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

extension ChainAssetListInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePricesData(result: result)
    }
}

extension ChainAssetListInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        guard let selectedAccountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId, selectedAccountId == accountId else {
            return
        }
        let updatedWallet = walletAssetManagementHelper.update(
            wallet,
            with: result,
            chainAsset: chainAsset
        )
        wallet = updatedWallet
        output?.didReceiveAccountInfo(result: result, for: chainAsset, wallet: updatedWallet)
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
        checkAssetVisibilityAndSave(wallet: wallet)
        output?.handleWalletChanged(wallet: event.account)
        resetAccountInfoSubscription()
        wallet = event.account
        output?.didReceive(accountInfosByChainAssets: [:])
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

extension ChainAssetListInteractor: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        saveCurrent(wallet, shouldNotify: false)
    }
}
