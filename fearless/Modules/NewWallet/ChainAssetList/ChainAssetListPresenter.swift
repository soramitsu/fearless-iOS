import Foundation
import RobinHood
import SoraFoundation
import SSFModels

private final class DeferredSheetActionCoordinator {
    private var didDismiss = false
    private var didRun = false
    private var pendingAction: (() -> Void)?

    func select(_ action: @escaping () -> Void) {
        guard !didRun, pendingAction == nil else {
            return
        }

        pendingAction = action
        runIfReady()
    }

    func dismiss() {
        didDismiss = true
        runIfReady()
    }

    private func runIfReady() {
        guard didDismiss, !didRun, let pendingAction else {
            return
        }

        didRun = true
        self.pendingAction = nil
        pendingAction()
    }
}

final class ChainAssetListPresenter {
    // MARK: Private properties

    private let lock = ReaderWriterLock()

    private weak var view: ChainAssetListViewInput?
    private let router: ChainAssetListRouterInput
    private let interactor: ChainAssetListInteractorInput

    private let viewModelFactory: ChainAssetListViewModelFactoryProtocol
    private var wallet: MetaAccountModel
    private var chainAssets: [ChainAsset]?

    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var displayType: AssetListDisplayType = .assetChains
    private var chainsWithIssue: [ChainIssue] = []
    private var chainSettings: [ChainSettings] = []

    private var networkFilter: NetworkManagmentFilter?
    private var searchText: String?
    private var pendingUniversalWalletRecovery: UniqueChainModel?

    // MARK: - Constructors

    init(
        interactor: ChainAssetListInteractorInput,
        router: ChainAssetListRouterInput,
        localizationManager: LocalizationManagerProtocol,
        wallet: MetaAccountModel,
        viewModelFactory: ChainAssetListViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        lock.concurrentlyRead {
            guard let chainAssets = self.chainAssets else {
                return
            }

            let accountInfosCopy = self.accountInfos
            let chainsWithIssue = self.chainsWithIssue
            let shouldRunManageAssetAnimate = self.interactor.shouldRunManageAssetAnimate
            let chainSettings = self.chainSettings

            let viewModel = self.viewModelFactory.buildViewModel(
                wallet: self.wallet,
                chainAssets: chainAssets,
                locale: self.selectedLocale,
                accountInfos: accountInfosCopy,
                chainsWithIssue: chainsWithIssue,
                shouldRunManageAssetAnimate: shouldRunManageAssetAnimate,
                displayType: self.displayType,
                chainSettings: chainSettings,
                networkFilter: self.networkFilter,
                search: self.searchText
            )

            DispatchQueue.main.async {
                self.view?.didReceive(viewModel: viewModel)
            }
        }
    }

    private func showMissingAccountOptions(chain: ChainModel) {
        let unused = (wallet.unusedChainIds ?? []).contains(chain.chainId)
        let uniqueChainModel = UniqueChainModel(
            meta: wallet,
            chain: chain
        )

        if requiresDedicatedUniversalAccount(for: chain) {
            presentUniversalWalletSetupOptions(uniqueChainModel: uniqueChainModel)
            return
        }

        let options: [MissingAccountOption?]
        options = [.create, .import, unused ? nil : .skip]

        let actions: [SheetAlertPresentableAction] = options.compactMap { option in
            switch option {
            case .create:
                let title = R.string.localizable
                    .createNewAccount(preferredLanguages: selectedLocale.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.router.showCreate(uniqueChainModel: uniqueChainModel, from: self?.view)
                }
            case .import:
                let title = R.string.localizable
                    .alreadyHaveAccount(preferredLanguages: selectedLocale.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.router.showImport(uniqueChainModel: uniqueChainModel, from: self?.view)
                }
            case .skip:
                let title = R.string.localizable
                    .missingAccountSkip(preferredLanguages: selectedLocale.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.interactor.markUnused(chain: uniqueChainModel.chain)
                }
            case .none:
                return nil
            }
        }

        router.presentAccountOptions(
            from: view,
            locale: selectedLocale,
            actions: actions
        )
    }

    private func presentUniversalWalletSetupOptions(uniqueChainModel: UniqueChainModel) {
        guard pendingUniversalWalletRecovery == nil else {
            return
        }

        let viewModel = Self.makeUniversalWalletSetupViewModel(
            locale: selectedLocale,
            useStoredSeed: { [weak self] in
                guard let self, self.pendingUniversalWalletRecovery == nil else {
                    return
                }

                self.pendingUniversalWalletRecovery = uniqueChainModel
                self.interactor.adoptStoredWalletSeed()
            }
        )
        router.present(viewModel: viewModel, from: view)
    }

    static func makeUniversalWalletSetupViewModel(
        locale: Locale?,
        useStoredSeed: @escaping () -> Void
    ) -> SheetAlertPresentableViewModel {
        let actionCoordinator = DeferredSheetActionCoordinator()
        let storedSeedAction = SheetAlertPresentableAction(
            title: "Add from wallet phrase",
            style: .pinkBackgroundWhiteText
        ) {
            actionCoordinator.select(useStoredSeed)
        }

        return SheetAlertPresentableViewModel(
            title: "One recovery phrase",
            message: "Bitcoin and Taira use the same recovery phrase as this wallet. " +
                "Adding either network configures both, and no new phrase is created.",
            actions: [storedSeedAction],
            closeAction: R.string.localizable.commonCancel(
                preferredLanguages: locale?.rLanguages
            ),
            dismissCompletion: {
                actionCoordinator.dismiss()
            }
        )
    }

    static func makeUniversalWalletRecoveryViewModel(
        locale: Locale?,
        importWalletPhrase: @escaping () -> Void
    ) -> SheetAlertPresentableViewModel {
        let actionCoordinator = DeferredSheetActionCoordinator()
        let importAction = SheetAlertPresentableAction(
            title: "Enter wallet recovery phrase",
            style: .pinkBackgroundWhiteText
        ) {
            actionCoordinator.select(importWalletPhrase)
        }

        return SheetAlertPresentableViewModel(
            title: "Wallet phrase required",
            message: "Enter the recovery phrase used to create or restore this wallet. " +
                "It will be verified against the existing wallet before Bitcoin and " +
                "Taira are added. A second phrase is never created. Raw-seed and JSON " +
                "wallets require a new mnemonic wallet and an asset migration.",
            actions: [importAction],
            closeAction: R.string.localizable.commonCancel(
                preferredLanguages: locale?.rLanguages
            ),
            dismissCompletion: {
                actionCoordinator.dismiss()
            }
        )
    }

    private func presentUniversalWalletRecoveryOptions(
        uniqueChainModel: UniqueChainModel
    ) {
        let chain = uniqueChainModel.chain
        let viewModel = Self.makeUniversalWalletRecoveryViewModel(
            locale: selectedLocale,
            importWalletPhrase: { [weak self] in
                guard let self else {
                    return
                }

                self.router.showImport(
                    uniqueChainModel: UniqueChainModel(
                        meta: self.wallet,
                        chain: chain
                    ),
                    from: self.view
                )
            }
        )
        router.present(viewModel: viewModel, from: view)
    }

    static func presentableStoredSeedAdoptionError(
        _ error: Error,
        locale: Locale?
    ) -> Error {
        if error is ErrorContentConvertible ||
            error is BaseOperationError ||
            (error as NSError).domain == NSURLErrorDomain {
            return error
        }

        return ConvenienceContentError(
            title: R.string.localizable.commonErrorGeneralTitle(
                preferredLanguages: locale?.rLanguages
            ),
            message: "The wallet seed could not be read. Unlock this device and try again. If it still fails, import the wallet's recovery phrase."
        )
    }

    static func requiresUniversalWalletRecoveryImport(for error: Error) -> Bool {
        (error as? UniversalWalletStoredSeedAdopter.AdoptionError) ==
            .storedWalletSeedUnavailable
    }

    private func requiresDedicatedUniversalAccount(for chain: ChainModel) -> Bool {
        UniversalWalletRegistry.bitcoinNetwork(for: chain.chainId) != nil ||
            UniversalWalletChainAccountSupport.chainId(
                chain.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            )
    }

    private func isAccountMissing(for chain: ChainModel) -> Bool {
        requiresDedicatedUniversalAccount(for: chain) &&
            !UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                in: wallet,
                for: chain.chainId
            )
    }

    private func isTaira(_ chain: ChainModel) -> Bool {
        UniversalWalletChainAccountSupport.chainId(
            chain.chainId,
            matches: UniversalWalletRegistry.taira.chainId
        )
    }
}

// MARK: - ChainAssetListViewOutput

extension ChainAssetListPresenter: ChainAssetListViewOutput {
    func didLoad(view: ChainAssetListViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel) {
        if isAccountMissing(for: viewModel.chainAsset.chain) {
            showMissingAccountOptions(chain: viewModel.chainAsset.chain)
            return
        }

        if viewModel.chainAsset.chain.isSupported {
            interactor.getAvailableChainAssets(chainAsset: viewModel.chainAsset) { [weak self] availableChainAssets in
                guard let strongSelf = self else { return }
                DispatchQueue.main.async {
                    if availableChainAssets.count > 1, strongSelf.displayType != .chain {
                        strongSelf.router.showAssetNetworks(
                            from: strongSelf.view,
                            chainAsset: viewModel.chainAsset
                        )
                    } else {
                        strongSelf.router.showChainAccount(
                            from: strongSelf.view,
                            chainAsset: viewModel.chainAsset
                        )
                    }
                }
            }
        } else {
            router.presentWarningAlert(
                from: view,
                config: WarningAlertConfig.unsupportedChainConfig(with: selectedLocale)
            ) { [weak self] in
                self?.router.showAppstoreUpdatePage()
            }
        }
    }

    func didTapAction(actionType: SwipableCellButtonType, viewModel: ChainAccountBalanceCellViewModel) {
        if isAccountMissing(for: viewModel.chainAsset.chain) {
            showMissingAccountOptions(chain: viewModel.chainAsset.chain)
            return
        }

        switch actionType {
        case .send:
            guard !isTaira(viewModel.chainAsset.chain) else {
                // Taira remains receive/read-only until the audited Iroha
                // signing and fee-readiness gate is explicitly enabled.
                return
            }
            router.showSendFlow(
                from: view,
                chainAsset: viewModel.chainAsset,
                wallet: wallet
            )
        case .receive:
            router.showReceiveFlow(
                from: view,
                chainAsset: viewModel.chainAsset,
                wallet: wallet
            )
        case .hide:
            interactor.hideChainAsset(viewModel.chainAsset)
        case .show:
            interactor.showChainAsset(viewModel.chainAsset)
        case .teleport:
            break
        }
    }

    func didPullToRefresh() {
        interactor.reload()
    }

    func didTapManageAsset() {
        router.showManageAsset(
            from: view,
            wallet: wallet,
            filter: networkFilter
        )
    }

    func didFinishManageAssetAnimate() {
        interactor.shouldRunManageAssetAnimate = false
    }

    func didTapResolveAccountIssue(for chain: ChainModel) {
        showMissingAccountOptions(chain: chain)
    }

    func didTapResolveNetworkIssue(for chain: ChainModel) {
        interactor.retryConnection(for: chain.chainId)
    }
}

// MARK: - Stored seed adoption

extension ChainAssetListPresenter {
    func didAdoptStoredWalletSeed(result: Result<MetaAccountModel, Error>) {
        switch result {
        case let .success(updatedWallet):
            pendingUniversalWalletRecovery = nil
            wallet = updatedWallet
            provideViewModel()
        case let .failure(error):
            Logger.shared.customError(error)

            let recovery = pendingUniversalWalletRecovery
            pendingUniversalWalletRecovery = nil

            if Self.requiresUniversalWalletRecoveryImport(for: error),
               let recovery {
                presentUniversalWalletRecoveryOptions(
                    uniqueChainModel: recovery
                )
                return
            }

            router.present(
                error: Self.presentableStoredSeedAdoptionError(
                    error,
                    locale: selectedLocale
                ),
                from: view,
                locale: selectedLocale
            )
        }
    }
}

// MARK: - ChainAssetListInteractorOutput

extension ChainAssetListPresenter: ChainAssetListInteractorOutput {
    func updateViewModel(isInitSearchState _: Bool) {
        provideViewModel()
    }

    func didReceiveWallet(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func handleWalletChanged(wallet: MetaAccountModel) {
        lock.exclusivelyWrite { [weak self] in
            self?.accountInfos = [:]
        }
        self.wallet = wallet
    }

    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            lock.exclusivelyWrite { [weak self] in
                guard let self = self else { return }
                self.chainAssets = chainAssets
            }
            provideViewModel()
        case let .failure(error):
            Logger.shared.customError(error)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let key = chainAsset.uniqueKey(accountId: accountId)

            let previousAccountInfo = lock.concurrentlyRead {
                accountInfos[key] ?? nil
            }
            let bothNil = (previousAccountInfo == nil && accountInfo == nil)

            guard previousAccountInfo != accountInfo, !bothNil else {
                return
            }

            lock.exclusivelyWrite { [weak self] in
                guard let self = self else { return }

                self.accountInfos[key] = accountInfo
            }
            provideViewModel()

        case let .failure(error):
            Logger.shared.customError(error)
        }
    }

    func didReceiveChainsWithIssues(_ issues: [ChainIssue]) {
        guard issues.isNotEmpty else {
            chainsWithIssue = []
            provideViewModel()
            return
        }
        lock.exclusivelyWrite { [weak self] in
            self?.chainsWithIssue = issues
        }
        provideViewModel()
    }

    func didReceive(accountInfosByChainAssets: [ChainAsset: AccountInfo?]) {
        let balances = accountInfosByChainAssets.reduce(into: [ChainAssetKey: AccountInfo?]()) { newDict, initialDict in
            let chainAsset = initialDict.key
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }

            let key = chainAsset.uniqueKey(accountId: accountId)
            newDict[key] = initialDict.value
        }

        lock.exclusivelyWrite { [weak self] in
            guard let self = self else { return }
            self.accountInfos = balances.merging(self.accountInfos, uniquingKeysWith: { old, _ in
                old
            })
        }
        provideViewModel()
    }

    func didReceive(chainSettings: [ChainSettings]) {
        lock.exclusivelyWrite { [weak self] in
            self?.chainSettings = chainSettings
        }
        provideViewModel()
    }
}

// MARK: - Localizable

extension ChainAssetListPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension ChainAssetListPresenter: ChainAssetListModuleInput {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor],
        networkFilter: NetworkManagmentFilter?
    ) {
        self.networkFilter = networkFilter
        searchText = filters.compactMap { filter -> String? in
            if case let .search(text) = filter {
                return text
            }

            return nil
        }.first

        let filteredByChain: Bool
        if let networkFilter, case .chain = networkFilter {
            filteredByChain = true
        } else {
            filteredByChain = false
        }

        let searchIsActive = filters.contains(where: { filter in
            if case ChainAssetsFetching.Filter.search = filter {
                return true
            }

            return false
        })

        if searchIsActive {
            displayType = .search
        } else if filteredByChain {
            displayType = .chain
        } else {
            displayType = .assetChains
        }

        // Network and search filters are presentation-only. Always keep every
        // enabled network subscribed so discovery cannot be disabled by UI state.
        interactor.updateChainAssets(using: [], sorts: sorts, useCashe: true)
    }
}

// MARK: - BannersModuleOutput?

extension ChainAssetListPresenter: BannersModuleOutput {
    func didTapCloseBanners() {}

    func reloadBannersView() {
        DispatchQueue.main.async {
            self.view?.reloadBanners()
        }
    }
}
