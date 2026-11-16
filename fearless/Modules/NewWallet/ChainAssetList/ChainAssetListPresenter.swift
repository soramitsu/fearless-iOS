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
    private let collapseStore = PortfolioCollapseStore()
    private let presentationScope = PortfolioCallbackScope()
    private let walletActionScope = PortfolioCallbackScope()
    private var presentedViewModel: ChainAssetListViewModel?
    /// The wallet home's one list: its own search field and network chips. The search screen drives the
    /// search through the module input instead.
    private let showsDiscovery: Bool
    /// Tokens arriving (kit v3 feel): balances that grow from a value already known play the receive feedback.
    private let arrivals = FWArrivalDetector()
    private let arrivalAnnouncer: FWArrivalAnnouncing

    // MARK: - Constructors

    init(
        interactor: ChainAssetListInteractorInput,
        router: ChainAssetListRouterInput,
        localizationManager: LocalizationManagerProtocol,
        wallet: MetaAccountModel,
        viewModelFactory: ChainAssetListViewModelFactoryProtocol,
        showsDiscovery: Bool = true,
        arrivalAnnouncer: FWArrivalAnnouncing = FWArrivalAnnouncer.shared
    ) {
        self.showsDiscovery = showsDiscovery
        self.arrivalAnnouncer = arrivalAnnouncer
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
            let request = presentationScope.invalidate()

            let accountInfosCopy = self.accountInfos
            let chainsWithIssue = self.chainsWithIssue
            let shouldRunManageAssetAnimate = self.interactor.shouldRunManageAssetAnimate
            let chainSettings = self.chainSettings

            // One list: the token rows are the only grouping. A stored network lens only brings up the
            // one-time note (see `didSelectLens`).
            var viewModel = self.viewModelFactory.buildViewModel(
                wallet: self.wallet,
                chainAssets: chainAssets,
                locale: self.selectedLocale,
                accountInfos: accountInfosCopy,
                chainsWithIssue: chainsWithIssue,
                shouldRunManageAssetAnimate: shouldRunManageAssetAnimate,
                displayType: self.displayType,
                chainSettings: chainSettings,
                networkFilter: self.networkFilter,
                search: Self.normalizedSearch(self.searchText),
                lens: .token
            )
            viewModel.showsDiscovery = self.showsDiscovery
            // The field's own text: a query is matched without its outer spaces, but the field keeps them.
            viewModel.searchText = self.searchText ?? ""

            presentationScope.deliver(request) {
                guard self.wallet.metaId == viewModel.walletId else { return }
                self.presentedViewModel = viewModel
                self.view?.didReceive(viewModel: viewModel)
            }
        }
    }

    /// A query of spaces is no search.
    static func normalizedSearch(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// A search shows its matches across the chosen networks; otherwise one network or the whole portfolio.
    static func displayType(search: String?, networkFilter: NetworkManagmentFilter?) -> AssetListDisplayType {
        if normalizedSearch(search) != nil {
            return .search
        }
        return networkFilter?.isChainSelected == true ? .chain : .assetChains
    }

    private func showMissingAccountOptions(chain: ChainModel) {
        let unused = (wallet.unusedChainIds ?? []).contains(chain.chainId)
        let uniqueChainModel = UniqueChainModel(
            meta: wallet,
            chain: chain
        )

        if requiresDedicatedUniversalAccount(for: chain) {
            guard UniversalWalletStoredSeedAdopter.canAddAppOwnedAccounts(to: wallet) else {
                presentUniversalWalletUnsupported()
                return
            }
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
        let languages = locale?.rLanguages
        let actionCoordinator = DeferredSheetActionCoordinator()
        let storedSeedAction = SheetAlertPresentableAction(
            title: R.string.localizable.universalSetupAction(preferredLanguages: languages),
            style: .pinkBackgroundWhiteText
        ) {
            actionCoordinator.select(useStoredSeed)
        }

        return SheetAlertPresentableViewModel(
            title: R.string.localizable.universalSetupTitle(preferredLanguages: languages),
            message: R.string.localizable.universalSetupMessage(preferredLanguages: languages),
            actions: [storedSeedAction],
            closeAction: R.string.localizable.commonCancel(
                preferredLanguages: languages
            ),
            dismissCompletion: {
                actionCoordinator.dismiss()
            }
        )
    }

    /// The stored phrase or seed could not be found. The wallet's own phrase, verified against
    /// it, adds the accounts; a wallet that never had one (raw seed or JSON without a phrase)
    /// can still reach Bitcoin, Solana and Taira through a phrase wallet in the wallet list.
    static func makeUniversalWalletRecoveryViewModel(
        locale: Locale?,
        importWalletPhrase: @escaping () -> Void,
        openWalletList: @escaping () -> Void
    ) -> SheetAlertPresentableViewModel {
        let languages = locale?.rLanguages
        let actionCoordinator = DeferredSheetActionCoordinator()
        let importAction = SheetAlertPresentableAction(
            title: R.string.localizable.universalRecoveryAction(preferredLanguages: languages),
            style: .pinkBackgroundWhiteText
        ) {
            actionCoordinator.select(importWalletPhrase)
        }
        let walletListAction = SheetAlertPresentableAction(
            title: R.string.localizable.universalOpenWalletsAction(preferredLanguages: languages)
        ) {
            actionCoordinator.select(openWalletList)
        }

        return SheetAlertPresentableViewModel(
            title: R.string.localizable.universalRecoveryTitle(preferredLanguages: languages),
            message: R.string.localizable.universalRecoveryMessage(preferredLanguages: languages),
            actions: [importAction, walletListAction],
            closeAction: R.string.localizable.commonCancel(
                preferredLanguages: languages
            ),
            dismissCompletion: {
                actionCoordinator.dismiss()
            }
        )
    }

    /// Native TON and EVM-only wallets, and seeds of an unknown origin, cannot hold Bitcoin,
    /// Solana and Taira accounts. Say so truthfully and lead to the wallet list, where a
    /// phrase wallet that can hold them is created or restored.
    static func makeUniversalWalletUnsupportedViewModel(
        wallet: MetaAccountModel,
        locale: Locale?,
        openWalletList: @escaping () -> Void
    ) -> SheetAlertPresentableViewModel {
        let languages = locale?.rLanguages
        let actionCoordinator = DeferredSheetActionCoordinator()
        let walletListAction = SheetAlertPresentableAction(
            title: R.string.localizable.universalOpenWalletsAction(preferredLanguages: languages),
            style: .pinkBackgroundWhiteText
        ) {
            actionCoordinator.select(openWalletList)
        }

        return SheetAlertPresentableViewModel(
            title: R.string.localizable.universalUnsupportedTitle(preferredLanguages: languages),
            message: UniversalWalletStoredSeedAdopter.canAddAppOwnedAccounts(to: wallet)
                ? R.string.localizable.universalUnsupportedSourceMessage(preferredLanguages: languages)
                : R.string.localizable.universalUnsupportedMessage(preferredLanguages: languages),
            actions: [walletListAction],
            closeAction: R.string.localizable.commonCancel(
                preferredLanguages: languages
            ),
            dismissCompletion: {
                actionCoordinator.dismiss()
            }
        )
    }

    private func presentUniversalWalletUnsupported() {
        let viewModel = Self.makeUniversalWalletUnsupportedViewModel(
            wallet: wallet,
            locale: selectedLocale,
            openWalletList: { [weak self] in
                self?.router.showWalletManagment(from: self?.view)
            }
        )
        router.present(viewModel: viewModel, from: view)
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
            },
            openWalletList: { [weak self] in
                self?.router.showWalletManagment(from: self?.view)
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
            message: R.string.localizable.universalSeedUnreadable(preferredLanguages: locale?.rLanguages)
        )
    }

    static func requiresUniversalWalletRecoveryImport(for error: Error) -> Bool {
        (error as? UniversalWalletStoredSeedAdopter.AdoptionError) ==
            .storedWalletSeedUnavailable
    }

    private func requiresDedicatedUniversalAccount(for chain: ChainModel) -> Bool {
        UniversalWalletRegistry.bitcoinNetwork(for: chain.chainId) != nil ||
            UniversalWalletRegistry.solanaNetwork(for: chain.chainId) != nil ||
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
    func didTapFunding(_ action: PortfolioFundingAction, walletId: String) {
        let request = walletActionScope.snapshot()
        let originalWallet = wallet
        guard currentFundingWallet(walletId, original: originalWallet, request: request),
              let chainAssets else { return }
        let assets = PortfolioFundingPolicy.candidates(chainAssets, wallet: wallet, action: action)
        let options = assets.map { asset in
            PortfolioFundingOption(
                title: asset.asset.symbolUppercased + " · " + asset.chain.name,
                subtitle: asset.asset.name
            ) { [weak self] in
                guard let self, self.currentFundingWallet(walletId, original: originalWallet, request: request),
                      let current = PortfolioFundingPolicy.candidates(
                          self.chainAssets ?? [],
                          wallet: self.wallet,
                          action: action
                      ).first(where: { $0.assetKey == asset.assetKey }) else { return }
                if action == .receive {
                    self.router.showReceiveFlow(from: self.view, chainAsset: current, wallet: self.wallet)
                } else {
                    self.showFundingProviders(for: current, originalWallet: originalWallet, request: request)
                }
            }
        }
        router.showFundingOptions(
            from: view,
            title: PortfolioStrings.text("portfolio.choose_network", locale: selectedLocale),
            options: options,
            locale: selectedLocale
        )
    }

    private func currentFundingWallet(_ walletId: String, original: MetaAccountModel, request: UUID) -> Bool {
        walletActionScope.isCurrent(request) && wallet == original && wallet.metaId == walletId &&
            presentedViewModel?.walletId == walletId && presentedViewModel?.showsFundingCard == true
    }

    private func showFundingProviders(for asset: ChainAsset, originalWallet: MetaAccountModel, request: UUID) {
        let actions = PortfolioFundingPolicy.purchaseActions(for: asset, wallet: wallet)
        let options = actions.map { action in
            PortfolioFundingOption(
                title: action.title,
                subtitle: asset.asset.symbolUppercased + " · " + asset.chain.name
            ) { [weak self] in
                guard let self, self.currentFundingWallet(
                    originalWallet.metaId,
                    original: originalWallet,
                    request: request
                ),
                    let current = PortfolioFundingPolicy.candidates(
                        self.chainAssets ?? [],
                        wallet: self.wallet,
                        action: .buy
                    ).first(where: { $0.assetKey == asset.assetKey }),
                    PortfolioFundingPolicy.purchaseActions(for: current, wallet: self.wallet)
                    .contains(where: { $0.title == action.title && $0.url == action.url }) else { return }
                self.router.showPurchase(from: self.view, action: action)
            }
        }
        router.showFundingOptions(
            from: view,
            title: PortfolioStrings.text("portfolio.buy", locale: selectedLocale),
            options: options,
            locale: selectedLocale
        )
    }

    /// The list has one grouping now. A wallet that kept the network lens sees the one-time note, and closing it
    /// (any lens answer) makes the token list its own.
    func didSelectLens(_: PortfolioLens, walletId: String) {
        guard wallet.metaId == walletId else { return }
        collapseStore.setLens(.token, walletId: walletId)
        provideViewModel()
    }

    func didSearch(_ query: String, walletId: String) {
        guard showsDiscovery, wallet.metaId == walletId else { return }
        searchText = query
        displayType = Self.displayType(search: query, networkFilter: networkFilter)
        provideViewModel()
    }

    func didSelectNetwork(_ identifier: String, walletId: String) {
        guard showsDiscovery, wallet.metaId == walletId else { return }
        let all = NetworkManagmentFilter.all.identifier
        let selected = (networkFilter ?? .all).identifier
        let target = identifier == selected ? all : identifier
        guard target != selected else { return }
        // The wallet's filter, as the header's network button saves it; the list follows the saved wallet.
        interactor.selectNetworkFilter(NetworkManagmentFilter(identifier: target), walletId: walletId)
    }

    func didTapMoreNetworks(walletId: String) {
        guard showsDiscovery, wallet.metaId == walletId else { return }
        router.showNetworkPicker(from: view, wallet: wallet)
    }

    func didTapTokenAction(actionType: SwipableCellButtonType, groupId: String, walletId: String) {
        let request = walletActionScope.snapshot()
        guard let row = currentTokenRow(groupId: groupId, walletId: walletId, request: request) else { return }
        if row.model.isSingleNetwork, let child = row.model.children.first,
           let cell = presentedViewModel?.tokenChildCells[child.chainAsset.assetKey] {
            didTapAction(actionType: actionType, viewModel: cell)
            return
        }
        let members = row.model.allChildren
        let locale = selectedLocale
        if actionType == .hide {
            let keys = Set(row.model.children.map { $0.chainAsset.assetKey })
            let hide = SheetAlertPresentableAction(
                title: R.string.localizable.swipableCellButtonHide(preferredLanguages: locale.rLanguages),
                style: .pinkBackgroundWhiteText
            ) { [weak self] in
                guard let self,
                      let current = self.currentTokenRow(groupId: groupId, walletId: walletId, request: request),
                      Set(current.model.children.map { $0.chainAsset.assetKey }) == keys else { return }
                current.model.children.forEach { self.interactor.hideChainAsset($0.chainAsset) }
            }
            router.showGroupHideConfirmation(
                from: view,
                viewModel: SheetAlertPresentableViewModel(
                    title: String(
                        format: PortfolioStrings.text("portfolio.hide_group", locale: locale),
                        row.model.symbol
                    ),
                    message: row.model.children.map {
                        $0.chainAsset.asset.symbolUppercased + " · " + $0.networkName
                    }.joined(separator: "\n"),
                    actions: [hide],
                    closeAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
                )
            )
            return
        }
        guard actionType == .send || actionType == .receive else { return }
        let available = members.filter { member in
            actionType == .receive || (member.value.transferable > .zero &&
                member.chainAsset.chain.isSupported && !isTaira(member.chainAsset.chain))
        }.sorted { lhs, rhs in
            if actionType == .send, lhs.value.transferable != rhs.value.transferable {
                return lhs.value.transferable > rhs.value.transferable
            }
            return (lhs.networkName, lhs.chainAsset.chain.chainId, lhs.chainAsset.asset.id) <
                (rhs.networkName, rhs.chainAsset.chain.chainId, rhs.chainAsset.asset.id)
        }
        if actionType == .send, available.count == 1, let member = available.first {
            performTokenAssetAction(
                actionType, key: member.chainAsset.assetKey, groupId: groupId, walletId: walletId, request: request
            )
            return
        }
        guard !available.isEmpty else { return }
        let options = available.map { member in
            PortfolioFundingOption(
                title: member.chainAsset.asset.symbolUppercased + " · " + member.networkName,
                subtitle: member.chainAsset.asset.name
            ) { [weak self] in
                self?.performTokenAssetAction(
                    actionType, key: member.chainAsset.assetKey, groupId: groupId, walletId: walletId, request: request
                )
            }
        }
        router.showFundingOptions(
            from: view,
            title: PortfolioStrings.text("portfolio.choose_network", locale: locale),
            options: options,
            locale: locale
        )
    }

    private func currentTokenRow(groupId: String, walletId: String, request: UUID) -> TokenGroupRowViewModel? {
        guard walletActionScope.isCurrent(request), wallet.metaId == walletId,
              let presentedViewModel, presentedViewModel.walletId == walletId else { return nil }
        return (presentedViewModel.tokenRows + presentedViewModel.zeroTokenRows).first { $0.model.id == groupId }
    }

    private func performTokenAssetAction(
        _ action: SwipableCellButtonType,
        key: AssetKey,
        groupId: String,
        walletId: String,
        request: UUID
    ) {
        guard let row = currentTokenRow(groupId: groupId, walletId: walletId, request: request),
              let member = row.model.allChildren.first(where: { $0.chainAsset.assetKey == key }),
              action != .send || (member.value.transferable > .zero &&
                  member.chainAsset.chain.isSupported && !isTaira(member.chainAsset.chain)),
              let cell = presentedViewModel?.tokenChildCells[key] else { return }
        didTapAction(actionType: action, viewModel: cell)
    }

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
            // A row is an exact network asset. Curated grouping never changes its destination.
            router.showChainAccount(from: view, chainAsset: viewModel.chainAsset)
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
            filter: networkFilter,
            visibilityFilter: .all
        )
    }

    func didTapHiddenAssetsNotIncluded() {
        // The count is wallet-wide like the header total, so Manage opens on every
        // network: a hidden asset is reachable whatever the portfolio filter shows.
        router.showManageAsset(
            from: view,
            wallet: wallet,
            filter: .all,
            visibilityFilter: .hidden
        )
    }

    func didTapTestnetAssetsNotIncluded() {
        // Testnets stay out of the list until the user shows one, which Manage offers
        // on every network.
        router.showManageAsset(
            from: view,
            wallet: wallet,
            filter: .all,
            visibilityFilter: .all
        )
    }

    func didTapReviewHiddenFunds() {
        router.showManageAsset(
            from: view,
            wallet: wallet,
            filter: .all,
            visibilityFilter: .hidden
        )
    }

    func didTapKeepHiddenFunds(assetKeys: [AssetKey]) {
        // Nothing is unhidden or written as a preference; only the notice goes.
        AssetVisibilityPreferenceStore.markHiddenFundsReviewed(assetKeys, walletId: wallet.metaId)
        provideViewModel()
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

            if (error as? UniversalWalletStoredSeedAdopter.AdoptionError) == .unsupportedSecretSource {
                presentUniversalWalletUnsupported()
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

// MARK: - Tokens arriving

private extension ChainAssetListPresenter {
    /// The token amount an arrival compares: free plus reserved, in the asset's smallest unit.
    static func arrivalAmount(_ accountInfo: AccountInfo??) -> Decimal? {
        guard let info = accountInfo ?? nil else { return nil }
        return Decimal(string: String(info.data.total))
    }

    func noteArrivalIfNeeded(accountInfo: AccountInfo?, chainAsset: ChainAsset, assetKey: String) {
        let walletId = wallet.metaId
        let grew = arrivals.observe(
            key: FWArrivalDetector.key(walletId: walletId, assetKey: assetKey),
            amount: Self.arrivalAmount(accountInfo),
            hidden: !AssetVisibilityPreferenceStore.isSelectable(walletId: walletId, chainAsset: chainAsset)
        )
        guard grew else { return }
        arrivalAnnouncer.announce(symbol: chainAsset.asset.symbol.uppercased(), locale: selectedLocale)
    }
}

// MARK: - ChainAssetListInteractorOutput

extension ChainAssetListPresenter: ChainAssetListInteractorOutput {
    func didFailNetworkFilter(error: Error) {
        // A wallet switched away while the filter was saving needs no message.
        if (error as? BaseOperationError) == .parentOperationCancelled {
            return
        }
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func updateViewModel(isInitSearchState _: Bool) {
        provideViewModel()
    }

    func didReceiveWallet(wallet: MetaAccountModel) {
        guard self.wallet.metaId == wallet.metaId else { return }
        lock.exclusivelyWrite { [weak self] in
            self?.wallet = wallet
        }
        if showsDiscovery {
            // A chip or the header's network list saved the wallet's filter.
            networkFilter = NetworkManagmentFilter(identifier: wallet.networkManagmentFilter)
            displayType = Self.displayType(search: searchText, networkFilter: networkFilter)
        }
        provideViewModel()
    }

    func handleWalletChanged(wallet: MetaAccountModel) {
        walletActionScope.invalidate()
        presentedViewModel = nil
        arrivals.reset()
        let request = presentationScope.invalidate()
        lock.exclusivelyWrite { [weak self] in
            self?.wallet = wallet
            self?.accountInfos = [:]
            self?.chainAssets = nil
            self?.chainsWithIssue = []
            self?.pendingUniversalWalletRecovery = nil
        }
        if showsDiscovery {
            // Another wallet starts with an empty search on its own network filter.
            searchText = nil
            networkFilter = NetworkManagmentFilter(identifier: wallet.networkManagmentFilter)
            displayType = Self.displayType(search: nil, networkFilter: networkFilter)
        }
        let showsDiscovery = showsDiscovery
        presentationScope.deliver(request) { [weak self] in
            self?.view?.didReceive(viewModel: ChainAssetListViewModel(
                displayState: .defaultList(cells: [], withAnimate: false), networkSections: [], walletId: wallet.metaId,
                lens: .token, showsDiscovery: showsDiscovery
            ))
        }
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
            noteArrivalIfNeeded(accountInfo: accountInfo, chainAsset: chainAsset, assetKey: key)

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
            // Values already known before this update: never announced as arrivals themselves.
            arrivals.seed(
                key: FWArrivalDetector.key(walletId: wallet.metaId, assetKey: key),
                amount: Self.arrivalAmount(initialDict.value)
            )
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
        let externalSearch = filters.compactMap { filter -> String? in
            if case let .search(text) = filter {
                return text
            }

            return nil
        }.first
        if let externalSearch {
            searchText = externalSearch
        } else if !showsDiscovery {
            // The search screen cleared its field. On the wallet home the field is the list's own and a
            // network change keeps its text.
            searchText = nil
        }
        displayType = Self.displayType(search: searchText, networkFilter: networkFilter)

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
