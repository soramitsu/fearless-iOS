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
    private let walletScope = PortfolioCallbackScope()
    private let catalogScope = PortfolioCallbackScope()
    private var accountInfoListener: PortfolioAccountInfoListener?

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
            isValid: { UniversalWalletChainAccountSupport.isValidBitcoinAccount($0) },
            into: &mergedAccounts
        )
        try mergeStoredSeedAccount(
            chainId: UniversalWalletRegistry.taira.chainId,
            adoptedAccounts: adoptedWallet.chainAccounts,
            currentAccounts: currentWallet.chainAccounts,
            isValid: UniversalWalletChainAccountSupport.isValidTairaAccount,
            into: &mergedAccounts
        )
        mergeStoredSeedSolanaAccount(
            adoptedAccounts: adoptedWallet.chainAccounts,
            currentAccounts: currentWallet.chainAccounts,
            into: &mergedAccounts
        )

        for chainId in [UniversalWalletRegistry.bitcoinTestnet.chainId,
                        UniversalWalletRegistry.tonMainnetRegistryEntry.chainId] {
            // These networks are enrolled only when absent. Keep any dedicated
            // key installed before or during adoption, including native TON.
            guard !currentWallet.chainAccounts.contains(where: {
                UniversalWalletChainAccountSupport.chainId($0.chainId, matches: chainId)
            }) else { continue }
            if chainId == UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
               currentWallet.legacyTonAccount != nil { continue }
            try mergeStoredSeedAccount(
                chainId: chainId,
                adoptedAccounts: adoptedWallet.chainAccounts,
                currentAccounts: currentWallet.chainAccounts,
                isValid: { account in
                    if chainId == UniversalWalletRegistry.bitcoinTestnet.chainId {
                        return UniversalWalletChainAccountSupport.isValidBitcoinAccount(account, chainId: chainId)
                    }
                    return account.cryptoType == CryptoType.ed25519.rawValue &&
                        !account.ethereumBased && account.accountId == account.publicKey &&
                        account.publicKey.count == 32 &&
                        UniversalWalletChainAccountSupport.address(for: chainId, publicKey: account.publicKey) != nil
                },
                into: &mergedAccounts
            )
        }

        return currentWallet.replacingChainAccounts(mergedAccounts)
    }

    /// Solana only fills an absent network (see
    /// `UniversalWalletAccountProvisioning.addingSolanaMainnetAccount`): a Solana account the
    /// wallet already has, or gained while adoption was running, is kept and is never a
    /// conflict.
    private static func mergeStoredSeedSolanaAccount(
        adoptedAccounts: Set<ChainAccountModel>,
        currentAccounts: Set<ChainAccountModel>,
        into mergedAccounts: inout Set<ChainAccountModel>
    ) {
        let isValid: (ChainAccountModel) -> Bool = {
            UniversalWalletChainAccountSupport.isValidSolanaAccount($0)
        }
        guard !currentAccounts.contains(where: isValid) else {
            return
        }

        adoptedAccounts.filter(isValid).forEach { mergedAccounts.insert($0) }
    }

    static func performAndPersistStoredSeedAdoption(
        walletSnapshot: MetaAccountModel,
        adopter: UniversalWalletStoredSeedAdopting,
        operationQueue: OperationQueue,
        walletSettings: SelectedWalletSettings,
        deliveryQueue: DispatchQueue = .main,
        currentWallet: @escaping () -> MetaAccountModel?,
        completion: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        performStoredSeedAdoption(
            walletSnapshot: walletSnapshot,
            adopter: adopter,
            operationQueue: operationQueue,
            deliveryQueue: deliveryQueue
        ) { result in
            let adoptedWallet: MetaAccountModel
            do {
                adoptedWallet = try result.get()
            } catch {
                completion(.failure(error))
                return
            }

            guard let interactorWallet = currentWallet(),
                  let selectedWallet = walletSettings.value else {
                completion(.failure(BaseOperationError.parentOperationCancelled))
                return
            }

            let latestWallet: MetaAccountModel
            do {
                latestWallet = try storedSeedAdoptionMergeBase(
                    walletSnapshot: walletSnapshot,
                    interactorWallet: interactorWallet,
                    selectedWallet: selectedWallet
                )
            } catch {
                completion(.failure(error))
                return
            }

            let walletToSave: MetaAccountModel
            do {
                walletToSave = try mergeStoredSeedAdoption(
                    adoptedWallet,
                    into: latestWallet
                )
            } catch {
                completion(.failure(error))
                return
            }

            walletSettings.save(
                value: walletToSave,
                runningCompletionIn: deliveryQueue
            ) { result in
                let savedWallet: MetaAccountModel
                do {
                    savedWallet = try result.get()
                } catch {
                    completion(.failure(error))
                    return
                }

                let activeWallet = walletSettings.value ?? savedWallet
                do {
                    let validatedWallet = try validatePersistedStoredSeedAdoption(
                        adoptedWallet,
                        activeWallet: activeWallet
                    )
                    completion(.success(validatedWallet))
                } catch {
                    completion(.failure(error))
                    return
                }
            }
        }
    }

    static func storedSeedAdoptionMergeBase(
        walletSnapshot: MetaAccountModel,
        interactorWallet: MetaAccountModel,
        selectedWallet: MetaAccountModel
    ) throws -> MetaAccountModel {
        guard interactorWallet.metaId == walletSnapshot.metaId,
              selectedWallet.metaId == walletSnapshot.metaId else {
            throw BaseOperationError.parentOperationCancelled
        }

        if interactorWallet == selectedWallet {
            return interactorWallet
        }

        if interactorWallet == walletSnapshot {
            return selectedWallet
        }

        if selectedWallet == walletSnapshot {
            return interactorWallet
        }

        // Two independently changed payloads cannot be reconciled without
        // risking loss of a concurrent wallet update. Let the user retry on
        // the latest stable snapshot instead.
        throw BaseOperationError.parentOperationCancelled
    }

    static func validatePersistedStoredSeedAdoption(
        _ adoptedWallet: MetaAccountModel,
        activeWallet: MetaAccountModel
    ) throws -> MetaAccountModel {
        let validatedWallet = try mergeStoredSeedAdoption(
            adoptedWallet,
            into: activeWallet
        )
        guard validatedWallet == activeWallet else {
            throw BaseOperationError.parentOperationCancelled
        }

        return activeWallet
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
        accountInfoListener = nil
    }

    private func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let accountInfoSubscriptionAdapter = dependencyContainer.buildDependencies(for: wallet).accountInfoSubscriptionAdapter

        if accountInfoListener == nil {
            accountInfoListener = PortfolioAccountInfoListener(wallet: wallet, scope: walletScope) { [weak self] result, chainAsset in
                self?.output?.didReceiveAccountInfo(result: result, for: chainAsset)
            }
        }

        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: accountInfoListener,
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
        let request = catalogScope.snapshot()
        let chainAssetFetching = dependencyContainer.buildDependencies(for: wallet).chainAssetFetching
        chainAssetFetching.fetch(
            shouldUseCache: false,
            filters: filters,
            sortDescriptors: sorts
        ) { [weak self] result in
            guard let result = result else { return }
            self?.catalogScope.deliver(request) { [weak self] in
                self?.output?.didReceiveChainAssets(result: result)
            }
        }
    }

    private func refreshRemoteBalances(for chainAssets: [ChainAsset]) {
        let chains = chainAssets.map(\.chain).uniq(predicate: { $0.chainId })
        let currentWallet = wallet
        let request = walletScope.snapshot()

        Task {
            let results = await withTaskGroup(
                of: [(ChainAsset, AccountInfo?)].self,
                returning: [(ChainAsset, AccountInfo?)].self
            ) { group in
                chains.forEach { chain in
                    group.addTask {
                        await Self.remoteAccountInfos(
                            for: chain,
                            wallet: currentWallet,
                            service: self.accountInfoRemoteService
                        )
                    }
                }

                var values: [(ChainAsset, AccountInfo?)] = []
                for await result in group {
                    values.append(contentsOf: result)
                }
                return values
            }

            await MainActor.run {
                guard self.walletScope.isCurrent(request) else { return }
                results.forEach { chainAsset, accountInfo in
                    self.output?.didReceiveAccountInfo(result: .success(accountInfo), for: chainAsset)
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

// MARK: - Remote balances

extension ChainAssetListInteractor {
    /// The balances one network's scan gives the list: what it read, or what the network last knew when the scan
    /// failed. An asset the scan could not read gets nothing, so the list keeps the balance it shows for it.
    static func remoteAccountInfos(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        service: AccountInfoRemoteService
    ) async -> [(ChainAsset, AccountInfo?)] {
        NetworkScanStateStore.markAttempt(for: chain, walletId: wallet.metaId)
        let infos: [ChainAssetId: AccountInfo?]
        var unread = Set<ChainAssetId>()
        do {
            infos = try await service.fetchAccountInfos(for: chain, wallet: wallet)
            NetworkScanStateStore.markSuccess(for: chain, walletId: wallet.metaId)
        } catch let incomplete as IncompleteAccountInfosError {
            NetworkScanStateStore.markFailure(for: chain, walletId: wallet.metaId)
            infos = incomplete.accountInfos
            unread = incomplete.unreadChainAssetIds
        } catch {
            NetworkScanStateStore.markFailure(for: chain, walletId: wallet.metaId)
            let retained = (service as? AccountInfoLastKnownBalanceProviding)?.lastKnownAccountInfos(
                for: chain,
                wallet: wallet
            ) ?? [:]
            guard retained.isNotEmpty else {
                return []
            }
            infos = retained
        }

        return chain.chainAssets
            .filter { !unread.contains($0.chainAssetId) }
            .map { ($0, infos[$0.chainAssetId] ?? nil) }
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

        self.filters = filters.map { filter in
            if case .enabled = filter { return .enabled(wallet: wallet) }
            return filter
        }
        self.sorts = sorts
        let currentWallet = wallet
        let request = catalogScope.invalidate()

        let chainAssetFetching = dependencyContainer.buildDependencies(for: currentWallet).chainAssetFetching
        chainAssetFetching.fetch(
            shouldUseCache: useCashe,
            filters: self.filters,
            sortDescriptors: sorts
        ) { [weak self] result in
            guard let result else { return }
            self?.catalogScope.deliver(request) { [weak self] in
                guard let self else { return }
                switch result {
                case let .success(chainAssets):
                    self.chainAssets = chainAssets
                    self.output?.didReceiveChainAssets(result: .success(chainAssets))

                    self.accountInfoFetchingProvider.fetch(for: chainAssets, wallet: currentWallet) { [weak self] accountInfosByChainAssets in
                        self?.catalogScope.deliver(request) { [weak self] in
                            guard let self else { return }
                            self.ethRemoteBalanceFetching.fetch(for: chainAssets, wallet: currentWallet) { _ in }
                            self.output?.didReceive(accountInfosByChainAssets: accountInfosByChainAssets)
                            self.subscribeToAccountInfo(for: chainAssets)
                            self.refreshUniversalBalances(for: chainAssets)
                        }
                    }
                case let .failure(error):
                    self.output?.didReceiveChainAssets(result: .failure(error))
                }
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

        let request = catalogScope.snapshot()
        accountInfoFetchingProvider.fetch(for: chainAssets, wallet: wallet) { [weak self] accountInfosByChainAssets in
            self?.catalogScope.deliver(request) { [weak self] in
                self?.output?.didReceive(accountInfosByChainAssets: accountInfosByChainAssets)
                self?.subscribeToAccountInfo(for: chainAssets)
            }
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
        let request = walletScope.snapshot()
        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [
                .enabled(wallet: wallet)
            ],
            sortDescriptors: []
        ) { [weak self] result in
            self?.walletScope.deliver(request) {
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
    }

    func hideChainAsset(_ chainAsset: ChainAsset) {
        Self.setExplicitlyHidden(
            true,
            chainAsset: chainAsset,
            walletId: wallet.metaId,
            eventCenter: eventCenter,
            output: output
        )
    }

    func showChainAsset(_ chainAsset: ChainAsset) {
        Self.setExplicitlyHidden(
            false,
            chainAsset: chainAsset,
            walletId: wallet.metaId,
            eventCenter: eventCenter,
            output: output
        )
    }

    /// The header total leaves hidden assets out, so the change goes out as an event
    /// for the wallet balance as well as this list.
    static func setExplicitlyHidden(
        _ hidden: Bool,
        chainAsset: ChainAsset,
        walletId: MetaAccountId,
        eventCenter: EventCenterProtocol,
        output: ChainAssetListInteractorOutput?,
        userDefaults: UserDefaults = .standard
    ) {
        AssetVisibilityPreferenceStore.setExplicitlyHidden(
            hidden,
            walletId: walletId,
            chainAsset: chainAsset,
            userDefaults: userDefaults
        )
        output?.updateViewModel(isInitSearchState: false)
        eventCenter.notify(
            with: AssetVisibilityPreferenceChangedEvent(
                walletId: walletId,
                assetKey: chainAsset.assetKey,
                preference: hidden ? .hidden : .shown
            )
        )
    }

    func retryConnection(for chainId: ChainModel.Id) {
        chainRegistry.retryConnection(for: chainId)
    }

    func adoptStoredWalletSeed() {
        let walletSnapshot = wallet
        Self.performAndPersistStoredSeedAdoption(
            walletSnapshot: walletSnapshot,
            adopter: storedSeedAdopter,
            operationQueue: operationQueue,
            walletSettings: walletSettings,
            currentWallet: { [weak self] in self?.wallet }
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(activeWallet):
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
        guard wallet.metaId == event.account.metaId else { return }
        let chainAccountsChanged = wallet.chainAccounts != event.account.chainAccounts
            || wallet.substrateAccountId != event.account.substrateAccountId
            || wallet.ethereumAddress != event.account.ethereumAddress
        if chainAccountsChanged {
            walletScope.invalidate()
            catalogScope.invalidate()
            resetAccountInfoSubscription()
        }
        if chainAccountsChanged {
            chainAssets = nil
            output?.handleWalletChanged(wallet: event.account)
        } else {
            output?.didReceiveWallet(wallet: event.account)
        }

        if wallet.selectedCurrency != event.account.selectedCurrency {
            output?.updateViewModel(isInitSearchState: false)
        }

        if wallet.unusedChainIds != event.account.unusedChainIds {
            output?.updateViewModel(isInitSearchState: false)
        }

        wallet = event.account

        if chainAccountsChanged {
            updateChainAssets(using: filters, sorts: sorts, useCashe: false)
        }
    }

    func processChainsUpdated(event _: ChainsUpdatedEvent) {
        updateChainAssets(using: filters, sorts: sorts, useCashe: false)
    }

    func processRemoteSubscriptionWasUpdated(event: WalletRemoteSubscriptionWasUpdatedEvent) {
        subscribeToAccountInfo(for: [event.chainAsset])
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        walletScope.invalidate()
        catalogScope.invalidate()
        resetAccountInfoSubscription()
        remoteFetchTimer?.invalidate()
        remoteFetchTimer = nil
        chainAssets = nil
        output?.handleWalletChanged(wallet: event.account)
        wallet = event.account
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
