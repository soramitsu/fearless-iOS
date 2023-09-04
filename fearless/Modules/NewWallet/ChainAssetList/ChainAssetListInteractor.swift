import UIKit
import RobinHood
import SoraKeystore
import SSFModels
import SCard

final class ChainAssetListInteractor {
    // MARK: - Private properties

    private weak var output: ChainAssetListInteractorOutput?

    private let assetRepository: AnyDataProviderRepository<AssetModel>
    private let operationQueue: OperationQueue
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private let eventCenter: EventCenter
    private var wallet: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let accountInfoFetching: AccountInfoFetchingProtocol
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
        accountInfoFetching: AccountInfoFetchingProtocol,
        dependencyContainer: ChainAssetListDependencyContainer
    ) {
        self.wallet = wallet
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.assetRepository = assetRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.accountRepository = accountRepository
        self.accountInfoFetching = accountInfoFetching
        self.dependencyContainer = dependencyContainer
    }

    // MARK: - Private methods

    private func save(_ updatedAccount: MetaAccountModel) {
        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
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
            filters: filters,
            sortDescriptors: sorts
        ) { [weak self] result in
            guard let strongSelf = self,
                  let result = result else {
                return
            }

            switch result {
            case let .success(chainAssets):
                self?.chainAssets = chainAssets
                self?.output?.didReceiveChainAssets(result: .success(chainAssets))
                self?.accountInfoFetching.fetch(for: chainAssets, wallet: strongSelf.wallet, completionBlock: { [weak self] accountInfosByChainAssets in
                    self?.subscribeToAccountInfo(for: chainAssets)
                    self?.output?.didReceive(accountInfosByChainAssets: accountInfosByChainAssets)
                })
                self?.subscribeToPrice(for: chainAssets)
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
        save(updatedWallet)
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
        save(updatedWallet)
    }

    func markUnused(chain: ChainModel) {
        var unusedChainIds = wallet.unusedChainIds ?? []
        unusedChainIds.append(chain.chainId)
        let updatedAccount = wallet.replacingUnusedChainIds(unusedChainIds)

        save(updatedAccount)
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
        save(updatedAccount)
    }

    func initSoraCard(completionBlock: @escaping (Result<SCard, Error>?) -> Void) {
        if let soraCard = SCard.shared {
            completionBlock(.success(soraCard))
        }
        let dependencies = dependencyContainer.buildDependencies(for: wallet)
        let chainAssetFetching = dependencies.chainAssetFetching
        let accountInfoSubscriptionAdapter = dependencies.accountInfoSubscriptionAdapter
        chainAssetFetching.fetch(filters: [.assetName("xor")], sortDescriptors: []) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case let .success(chainAssets):
                if let soraChainAsset = chainAssets.first(where: { chainAsset in
                    chainAsset.chain.chainId == Chain.soraMain.genesisHash
                }) {
                    DispatchQueue.main.async {
                        let soraCardInitializer = SoraCardInitializer(
                            wallet: strongSelf.wallet,
                            soraChainAsset: soraChainAsset,
                            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter
                        )
                        let soraCard = soraCardInitializer.initSoraCard()
                        completionBlock(.success(soraCard))
                    }
                }
            default:
                DispatchQueue.main.async {
                    completionBlock(nil)
                }
            }
        }
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
        updateChainAssets(using: filters, sorts: sorts)
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

    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return
        }

        resetAccountInfoSubscription()
        self.wallet = wallet
        output?.handleWalletChanged(wallet: wallet)
        updateChainAssets(using: filters, sorts: sorts)
    }
}

extension ChainAssetListInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        output?.didReceiveChainsWithIssues(issues)
    }
}
