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
    private let userDefaultsStorage: SettingsManagerProtocol
    private let chainsIssuesCenter: ChainsIssuesCenter
    private let chainSettingsRepository: AsyncAnyRepository<ChainSettings>
    private let chainRegistry: ChainRegistryProtocol
    private let accountInfoRemoteService: AccountInfoRemoteService
    private let pricesService: PricesServiceProtocol
    private let operationQueue: OperationQueue
    private let storedSeedAdopter: UniversalWalletStoredSeedAdopting
    private let walletSettings: SelectedWalletSettings

    private let mutex = NSLock()
    private var remoteFetchTimer: Timer?

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    weak var presenter: ChainAssetListInteractorOutput?

    init(
        wallet: MetaAccountModel,
        eventCenter: EventCenter,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        accountInfoFetchingProvider: AccountInfoFetching,
        dependencyContainer: ChainAssetListDependencyContainer,
        ethRemoteBalanceFetching: EthereumRemoteBalanceFetching,
        chainAssetFetching: ChainAssetFetchingProtocol,
        userDefaultsStorage: SettingsManagerProtocol,
        chainsIssuesCenter: ChainsIssuesCenter,
        chainSettingsRepository: AsyncAnyRepository<ChainSettings>,
        chainRegistry: ChainRegistryProtocol,
        accountInfoRemoteService: AccountInfoRemoteService,
        pricesService: PricesServiceProtocol,
        operationQueue: OperationQueue,
        storedSeedAdopter: UniversalWalletStoredSeedAdopting = UniversalWalletStoredSeedAdopter(),
        walletSettings: SelectedWalletSettings = .shared
    ) {
        self.wallet = wallet
        self.eventCenter = eventCenter
        self.accountRepository = accountRepository
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.dependencyContainer = dependencyContainer
        self.ethRemoteBalanceFetching = ethRemoteBalanceFetching
        self.chainAssetFetching = chainAssetFetching
        self.userDefaultsStorage = userDefaultsStorage
        self.chainsIssuesCenter = chainsIssuesCenter
        self.chainSettingsRepository = chainSettingsRepository
        self.chainRegistry = chainRegistry
        self.accountInfoRemoteService = accountInfoRemoteService
        self.pricesService = pricesService
        self.operationQueue = operationQueue
        self.storedSeedAdopter = storedSeedAdopter
        self.walletSettings = walletSettings
    }

    static func performStoredSeedAdoption(
        walletSnapshot: MetaAccountModel,
        adopter: UniversalWalletStoredSeedAdopting,
        operationQueue: OperationQueue,
        deliveryQueue: DispatchQueue = .main,
        completion: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        let operation = ClosureOperation {
            try adopter.adoptStoredSecret(for: walletSnapshot)
        }

        operation.completionBlock = { [weak operation] in
            deliverStoredSeedAdoptionResult(
                from: operation,
                deliveryQueue: deliveryQueue,
                completion: completion
            )
        }

        operationQueue.addOperation(operation)
    }

    static func deliverStoredSeedAdoptionResult(
        from operation: BaseOperation<MetaAccountModel>?,
        deliveryQueue: DispatchQueue,
        completion: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        // A finished operation can be released as soon as its completion block
        // returns. Materialize the result before crossing the async queue
        // boundary so account creation can never disappear silently.
        let result = operation?.result ?? .failure(BaseOperationError.parentOperationCancelled)
        deliveryQueue.async {
            completion(result)
        }
    }

    static func mergeStoredSeedAdoption(
        _ adoptedWallet: MetaAccountModel,
        into currentWallet: MetaAccountModel
    ) throws -> MetaAccountModel {
        guard adoptedWallet.metaId == currentWallet.metaId,
              adoptedWallet.substrateAccountId == currentWallet.substrateAccountId,
              adoptedWallet.substratePublicKey == currentWallet.substratePublicKey,
              adoptedWallet.substrateCryptoType == currentWallet.substrateCryptoType else {
            throw BaseOperationError.parentOperationCancelled
        }

        var mergedAccounts = currentWallet.chainAccounts
        try mergeStoredSeedAccount(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            adoptedAccounts: adoptedWallet.chainAccounts,
            currentAccounts: currentWallet.chainAccounts,
            isValid: { account in
                UniversalWalletChainAccountSupport.isValidBitcoinAccount(account)
            },
            into: &mergedAccounts
        )
        try mergeStoredSeedAccount(
            chainId: UniversalWalletRegistry.taira.chainId,
            adoptedAccounts: adoptedWallet.chainAccounts,
            currentAccounts: currentWallet.chainAccounts,
            isValid: UniversalWalletChainAccountSupport.isValidTairaAccount,
            into: &mergedAccounts
        )

        return currentWallet.replacingChainAccounts(mergedAccounts)
    }

    private static func mergeStoredSeedAccount(
        chainId: ChainModel.Id,
        adoptedAccounts: Set<ChainAccountModel>,
        currentAccounts: Set<ChainAccountModel>,
        isValid: (ChainAccountModel) -> Bool,
        into mergedAccounts: inout Set<ChainAccountModel>
    ) throws {
        let adoptedMatches = adoptedAccounts.filter {
            UniversalWalletChainAccountSupport.chainId($0.chainId, matches: chainId)
        }
        guard adoptedMatches.count == 1,
              let adoptedAccount = adoptedMatches.first,
              isValid(adoptedAccount) else {
            throw UniversalWalletStoredSeedAdopter.AdoptionError
                .conflictingUniversalWalletAccount
        }

        let currentMatches = currentAccounts.filter {
            UniversalWalletChainAccountSupport.chainId($0.chainId, matches: chainId)
        }
        guard currentMatches.count <= 1 else {
            throw UniversalWalletStoredSeedAdopter.AdoptionError
                .conflictingUniversalWalletAccount
        }

        if let currentAccount = currentMatches.first {
            guard isValid(currentAccount),
                  currentAccount.accountId == adoptedAccount.accountId,
                  currentAccount.publicKey == adoptedAccount.publicKey,
                  currentAccount.cryptoType == adoptedAccount.cryptoType,
                  currentAccount.ethereumBased == adoptedAccount.ethereumBased else {
                throw UniversalWalletStoredSeedAdopter.AdoptionError
                    .conflictingUniversalWalletAccount
            }
        } else {
            mergedAccounts.insert(adoptedAccount)
        }
    }

    // MARK: - Private methods

    private func save(_ updatedAccount: MetaAccountModel, shouldNotify: Bool) {
        SelectedWalletSettings.shared.performSave(value: updatedAccount) { [weak self] result in
            switch result {
            case .success:
                guard shouldNotify else { return }
                self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: updatedAccount))
            case .failure:
                break
            }
        }
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
            deliveryOn: accountInfosDeliveryQueue,
            notifyJustWhenUpdated: false
        )
    }

    private func getChainSettings() {
        Task {
            let settings = try await chainSettingsRepository.fetchAll()
            output?.didReceive(chainSettings: settings)
        }
    }

    private func getUpdatedChainAssets() {
        let chainAssetFetching = dependencyContainer.buildDependencies(for: wallet).chainAssetFetching
        chainAssetFetching.fetch(
            shouldUseCache: false,
            filters: filters,
            sortDescriptors: sorts
        ) { [weak self] result in
            guard let result = result else { return }
            self?.output?.didReceiveChainAssets(result: result)
        }
    }

    private func refreshRemoteBalances(for chainAssets: [ChainAsset]) {
        let chains = chainAssets.map(\.chain).uniq(predicate: { $0.chainId })
        let currentWallet = wallet

        Task {
            let results = await withTaskGroup(
                of: (ChainModel, [ChainAssetId: AccountInfo?])?.self,
                returning: [(ChainModel, [ChainAssetId: AccountInfo?])].self
            ) { group in
                chains.forEach { chain in
                    group.addTask {
                        NetworkScanStateStore.markAttempt(for: chain, walletId: currentWallet.metaId)
                        do {
                            let infos = try await self.accountInfoRemoteService.fetchAccountInfos(
                                for: chain,
                                wallet: currentWallet
                            )
                            NetworkScanStateStore.markSuccess(for: chain, walletId: currentWallet.metaId)
                            return (chain, infos)
                        } catch {
                            NetworkScanStateStore.markFailure(for: chain, walletId: currentWallet.metaId)
                            if let lastKnownProvider = self.accountInfoRemoteService as? AccountInfoLastKnownBalanceProviding {
                                let retained = lastKnownProvider.lastKnownAccountInfos(
                                    for: chain,
                                    wallet: currentWallet
                                )
                                if retained.isNotEmpty {
                                    return (chain, retained)
                                }
                            }
                            return nil
                        }
                    }
                }

                var values: [(ChainModel, [ChainAssetId: AccountInfo?])] = []
                for await result in group {
                    if let result {
                        values.append(result)
                    }
                }
                return values
            }

            await MainActor.run {
                results.forEach { chain, infos in
                    chain.chainAssets.forEach { chainAsset in
                        let accountInfo = infos[chainAsset.chainAssetId] ?? nil
                        self.output?.didReceiveAccountInfo(result: .success(accountInfo), for: chainAsset)
                    }
                }
            }
        }
    }

    private func refreshUniversalBalances(for chainAssets: [ChainAsset]) {
        let universalChainAssets = chainAssets.filter {
            UniversalWalletChainAccountSupport.isUniversalWalletChain($0.chain.chainId)
        }
        guard universalChainAssets.isNotEmpty else {
            return
        }

        refreshRemoteBalances(for: universalChainAssets)
    }
}

// MARK: - ChainAssetListInteractorInput

extension ChainAssetListInteractor: ChainAssetListInteractorInput {
    var shouldRunManageAssetAnimate: Bool {
        get {
            userDefaultsStorage.shouldRunManageAssetAnimate
        }
        set {
            guard userDefaultsStorage.shouldRunManageAssetAnimate else {
                return
            }
            userDefaultsStorage.shouldRunManageAssetAnimate = false
        }
    }

    func setup(with output: ChainAssetListInteractorOutput) {
        self.output = output

        eventCenter.add(observer: self, dispatchIn: .main)
        chainsIssuesCenter.addIssuesListener(self, getExisting: true)
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
                self?.chainAssets = chainAssets
                self?.output?.didReceiveChainAssets(result: .success(chainAssets))

                self?.accountInfoFetchingProvider.fetch(for: chainAssets, wallet: strongSelf.wallet) { accountInfosByChainAssets in
                    self?.ethRemoteBalanceFetching.fetch(for: chainAssets, wallet: strongSelf.wallet) { _ in }
                    self?.output?.didReceive(accountInfosByChainAssets: accountInfosByChainAssets)
                    self?.subscribeToAccountInfo(for: chainAssets)
                    self?.refreshUniversalBalances(for: chainAssets)
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

        guard remoteFetchTimer == nil else {
            return
        }

        remoteFetchTimer = Timer.scheduledTimer(withTimeInterval: Constants.remoteFetchTimerTimeInterval, repeats: false, block: { [weak self] timer in
            timer.invalidate()
            self?.remoteFetchTimer = nil
        })

        ethRemoteBalanceFetching.fetch(for: chainAssets, wallet: wallet) { _ in }
        refreshRemoteBalances(for: chainAssets)
        pricesService.updatePrices()
    }

    func getAvailableChainAssets(chainAsset: ChainAsset, completion: @escaping (([ChainAsset]) -> Void)) {
        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [
                .enabled(wallet: wallet)
            ],
            sortDescriptors: []
        ) { result in
            switch result {
            case let .success(availableChainAssets):
                completion(
                    CuratedAssetRelationshipResolver.relatedChainAssets(
                        to: chainAsset,
                        among: availableChainAssets
                    )
                )
            default:
                completion([])
            }
        }
    }

    func hideChainAsset(_ chainAsset: ChainAsset) {
        AssetVisibilityPreferenceStore.setExplicitlyHidden(
            true,
            walletId: wallet.metaId,
            chainAsset: chainAsset
        )
        output?.updateViewModel(isInitSearchState: false)
    }

    func showChainAsset(_ chainAsset: ChainAsset) {
        AssetVisibilityPreferenceStore.setExplicitlyHidden(
            false,
            walletId: wallet.metaId,
            chainAsset: chainAsset
        )
        output?.updateViewModel(isInitSearchState: false)
    }

    func retryConnection(for chainId: ChainModel.Id) {
        chainRegistry.retryConnection(for: chainId)
    }

    func adoptStoredWalletSeed() {
        let walletSnapshot = wallet
        Self.performStoredSeedAdoption(
            walletSnapshot: walletSnapshot,
            adopter: storedSeedAdopter,
            operationQueue: operationQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(updatedWallet):
                guard self.wallet.metaId == walletSnapshot.metaId,
                      self.walletSettings.value?.metaId == walletSnapshot.metaId else {
                    self.output?.didAdoptStoredWalletSeed(
                        result: .failure(BaseOperationError.parentOperationCancelled)
                    )
                    return
                }

                let walletToSave: MetaAccountModel
                do {
                    walletToSave = try Self.mergeStoredSeedAdoption(
                        updatedWallet,
                        into: self.wallet
                    )
                } catch {
                    self.output?.didAdoptStoredWalletSeed(result: .failure(error))
                    return
                }

                self.walletSettings.save(
                    value: walletToSave,
                    runningCompletionIn: .main
                ) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case let .success(savedWallet):
                        let activeWallet = self.walletSettings.value ?? savedWallet
                        guard activeWallet.metaId == savedWallet.metaId,
                              UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                                  in: activeWallet,
                                  for: UniversalWalletRegistry.bitcoinMainnet.chainId
                              ),
                              UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                                  in: activeWallet,
                                  for: UniversalWalletRegistry.taira.chainId
                              ) else {
                            self.output?.didAdoptStoredWalletSeed(
                                result: .failure(BaseOperationError.parentOperationCancelled)
                            )
                            return
                        }

                        self.wallet = activeWallet
                        self.resetAccountInfoSubscription()
                        self.updateChainAssets(
                            using: self.filters,
                            sorts: self.sorts,
                            useCashe: false
                        )
                        self.eventCenter.notify(
                            with: MetaAccountModelChangedEvent(account: activeWallet)
                        )
                        self.output?.didAdoptStoredWalletSeed(result: .success(activeWallet))
                    case let .failure(error):
                        self.output?.didAdoptStoredWalletSeed(result: .failure(error))
                    }
                }
            case let .failure(error):
                self.output?.didAdoptStoredWalletSeed(result: .failure(error))
            }
        }
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
    static func invalidateViewModel(
        for event: AssetVisibilityPreferenceChangedEvent,
        walletId: MetaAccountId,
        output: ChainAssetListInteractorOutput?
    ) {
        guard event.walletId == walletId else {
            return
        }

        output?.updateViewModel(isInitSearchState: false)
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        let chainAccountsChanged = wallet.chainAccounts != event.account.chainAccounts
        output?.didReceiveWallet(wallet: event.account)

        if wallet.selectedCurrency != event.account.selectedCurrency {
            output?.updateViewModel(isInitSearchState: false)
        }

        if wallet.unusedChainIds != event.account.unusedChainIds {
            output?.updateViewModel(isInitSearchState: false)
        }

        wallet = event.account

        if chainAccountsChanged {
            resetAccountInfoSubscription()
            updateChainAssets(using: filters, sorts: sorts, useCashe: false)
        }
    }

    func processChainsUpdated(event _: ChainsUpdatedEvent) {
        updateChainAssets(using: filters, sorts: sorts, useCashe: false)
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
        wallet = event.account
        resetAccountInfoSubscription()
        output?.didReceive(accountInfosByChainAssets: [:])
        updateChainAssets(using: filters, sorts: sorts, useCashe: false)
    }

    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
        updateChainAssets(using: filters, sorts: sorts, useCashe: false)
    }

    func processPricesUpdated() {
        getUpdatedChainAssets()
    }

    func processAssetVisibilityPreferenceChanged(event: AssetVisibilityPreferenceChangedEvent) {
        Self.invalidateViewModel(
            for: event,
            walletId: wallet.metaId,
            output: output
        )
    }
}

extension ChainAssetListInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        output?.didReceiveChainsWithIssues(issues)
    }
}
