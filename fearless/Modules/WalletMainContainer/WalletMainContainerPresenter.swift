import Foundation
import SoraFoundation
import SSFModels
import SSFQRService
import SSFUtils
import UIKit

final class WalletMainContainerPresenter {
    // MARK: Private properties

    private weak var balanceInfoModuleInput: BalanceInfoModuleInput?
    private weak var assetListModuleInput: ChainAssetListModuleInput?
    private weak var nftModuleInput: MainNftContainerModuleInput?
    private weak var view: WalletMainContainerViewInput?
    private let router: WalletMainContainerRouterInput
    private let interactor: WalletMainContainerInteractorInput

    private var wallet: MetaAccountModel
    private let viewModelFactory: WalletMainContainerViewModelFactoryProtocol

    // MARK: - State

    private var selectedChains: [ChainModel]?
    private var selectedNetworkManagmentFilter: NetworkManagmentFilter?
    private var pendingStoredRecordsNotices: [StoredWalletRecordsNotice] = []
    /// Universal accounts the selected wallet's password does not protect yet, until the
    /// once-per-wallet notice about them is shown.
    private var pendingPasswordNoticeAccounts: [UniversalWalletNoPasswordAccount] = []
    /// Funds that reached watched old addresses, shown after the other notices.
    private var pendingOldAddressArrivals: [UniversalWalletOldAddressArrival] = []
    private let updateSecurityNotice: UpdateSecurityNoticeTracking
    private var isUpdateSecurityNoticeActive = false

    // MARK: - Constructors

    init(
        balanceInfoModuleInput: BalanceInfoModuleInput?,
        assetListModuleInput: ChainAssetListModuleInput?,
        nftModuleInput: MainNftContainerModuleInput?,
        wallet: MetaAccountModel,
        viewModelFactory: WalletMainContainerViewModelFactoryProtocol,
        interactor: WalletMainContainerInteractorInput,
        router: WalletMainContainerRouterInput,
        updateSecurityNotice: UpdateSecurityNoticeTracking,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.balanceInfoModuleInput = balanceInfoModuleInput
        self.assetListModuleInput = assetListModuleInput
        self.nftModuleInput = nftModuleInput
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.updateSecurityNotice = updateSecurityNotice

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            selectedFilter: selectedNetworkManagmentFilter ?? .all,
            selectedChains: selectedChains ?? [],
            selectedMetaAccount: wallet,
            locale: selectedLocale
        )
        DispatchQueue.main.async {
            self.view?.didReceiveViewModel(viewModel)
        }
    }

    private func walletConnect(with uri: String) {
        Task {
            do {
                try await interactor.walletConnect(uri: uri)
            } catch {
                _ = await MainActor.run(body: {
                    router.present(error: error, from: view, locale: selectedLocale)
                })
            }
        }
    }
}

// MARK: - WalletMainContainerViewOutput

extension WalletMainContainerPresenter: WalletMainContainerViewOutput {
    func addressDidCopied() {
        router.presentStatus(
            with: AddressCopiedEvent(locale: selectedLocale),
            animated: true
        )
    }

    func didLoad(view: WalletMainContainerViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()

        if updateSecurityNotice.isPending {
            isUpdateSecurityNoticeActive = true
            presentUpdateSecurityNotice(retriesLeft: StoredRecordsNoticeConstants.presentationRetries)
        }
    }

    func didTapOnSwitchWallet() {
        router.showWalletManagment(from: view, moduleOutput: self)
    }

    func didTapOnQR() {
        router.showScanQr(from: view, moduleOutput: self)
    }

    func didTapSearch() {
        router.showSearch(from: view, wallet: wallet)
    }

    func didTapSelectNetwork() {
        router.showSelectNetwork(
            from: view,
            wallet: wallet,
            delegate: nil
        )
    }

    func didTapOnBalance() {
        router.showSelectCurrency(
            from: view,
            wallet: wallet
        )
    }

    func didTapAccountScore() {
        let address = wallet.ethereumAddress?.toHex(includePrefix: true)
        router.presentAccountScore(address: address, from: view)
    }
}

// MARK: - WalletMainContainerInteractorOutput

extension WalletMainContainerPresenter: WalletMainContainerInteractorOutput {
    func didReceiveSelected(tuple: (select: NetworkManagmentFilter, chains: [SSFModels.ChainModel])) {
        selectedNetworkManagmentFilter = tuple.select

        let chains = tuple.chains
        var selectedChains: [ChainModel] = []
        var filters: [ChainAssetsFetching.Filter] = []

        switch tuple.select {
        case let .chain(id):
            guard let chain = chains.first(where: { $0.chainId == id }) else {
                return
            }
            selectedChains = [chain]
            filters.append(.chainId(chain.chainId))
        case .all:
            selectedChains = chains
        case .popular:
            selectedChains = chains.filter { $0.rank != nil }
            filters.append(.chainIds(selectedChains.map { $0.chainId }))
        case .favourite:
            selectedChains = chains.filter { wallet.favouriteChainIds.contains($0.chainId) == true }
            filters.append(.chainIds(selectedChains.map { $0.chainId }))
        }
        self.selectedChains = selectedChains

        provideViewModel()

        assetListModuleInput?.updateChainAssets(
            using: filters,
            sorts: [],
            networkFilter: tuple.select
        )
        nftModuleInput?.didSelect(chains: selectedChains)
    }

    func didReceiveError(_ error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func didReceiveAccount(_ account: MetaAccountModel) {
        wallet = account
        provideViewModel()

        balanceInfoModuleInput?.replace(infoType: .networkManagement(wallet: account))
    }

    func didReceiveControllerAccountIssue(issue: ControllerAccountIssue, hasStashItem: Bool) {
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.controllerAccountIssueAction(preferredLanguages: selectedLocale.rLanguages),
            style: .pinkBackgroundWhiteText
        ) { [weak self] in
            guard let strongSelf = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if hasStashItem {
                    strongSelf.router.showControllerAccountFlow(
                        from: strongSelf.view,
                        chainAsset: issue.chainAsset,
                        wallet: issue.wallet
                    )
                } else {
                    strongSelf.router.showMainStaking(from: strongSelf.view)
                }
            }
        }

        router.present(
            message: R.string.localizable.stakingControllerDeprecatedDescription(
                issue.chainAsset.chain.name,
                preferredLanguages: selectedLocale.rLanguages
            ),
            title: R.string.localizable.commonImportant(preferredLanguages: selectedLocale.rLanguages),
            closeAction: nil,
            from: view,
            actions: [action]
        )
    }

    func didReceiveStashAccountIssue(address: String) {
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.stashAccountIssueAction(
                preferredLanguages: selectedLocale.rLanguages
            ),
            style: .pinkBackgroundWhiteText
        ) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.showImportWallet(defaultSource: .mnemonic, from: strongSelf.view)
        }

        router.present(
            message: R.string.localizable.stashAccountIssueMessage(
                address,
                preferredLanguages: selectedLocale.rLanguages
            ),
            title: R.string.localizable.commonImportant(preferredLanguages: selectedLocale.rLanguages),
            closeAction: nil,
            from: view,
            actions: [action]
        )
    }

    func didReceiveNftAvailability(isNftAvailable: Bool) {
        view?.didReceiveNftAvailability(isNftAvailable: isNftAvailable)
    }

    func didReceiveStoredWalletRecordsNotices(_ notices: [StoredWalletRecordsNotice]) {
        pendingStoredRecordsNotices = notices
        presentNextStoredRecordsNotice(retriesLeft: StoredRecordsNoticeConstants.presentationRetries)
    }

    func didReceiveUniversalWalletNoPasswordAccounts(_ accounts: [UniversalWalletNoPasswordAccount]) {
        pendingPasswordNoticeAccounts = accounts
        presentNextStoredRecordsNotice(retriesLeft: StoredRecordsNoticeConstants.presentationRetries)
    }

    func didReceiveUniversalWalletOldAddressArrivals(_ arrivals: [UniversalWalletOldAddressArrival]) {
        pendingOldAddressArrivals = arrivals
        presentNextStoredRecordsNotice(retriesLeft: StoredRecordsNoticeConstants.presentationRetries)
    }

    func didReceiveUniversalWalletSwitchOutcomes(
        _ outcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome],
        for accounts: [UniversalWalletNoPasswordAccount]
    ) {
        router.present(
            viewModel: UniversalWalletPasswordNotice.outcomes(outcomes, for: accounts, locale: selectedLocale),
            from: view
        )
    }
}

// MARK: - Stored wallet records notices

private struct StoredRecordsNoticeContent {
    let title: String
    let message: String
    let actions: [SheetAlertPresentableAction]
}

private enum StoredRecordsNoticeConstants {
    static let presentationRetries = 5
    static let retryDelay: TimeInterval = 1
}

private extension WalletMainContainerPresenter {
    /// Shows the pending notices one after another. A notice counts as shown only once the
    /// user has closed it; one that could not be presented stays pending for the next launch.
    func presentNextStoredRecordsNotice(retriesLeft: Int) {
        // The update notice goes first; these follow once it is closed.
        guard !isUpdateSecurityNoticeActive else {
            return
        }
        guard let notice = pendingStoredRecordsNotices.first else {
            presentPasswordNotice(retriesLeft: retriesLeft)
            return
        }

        guard
            let controller = view?.controller,
            controller.viewIfLoaded?.window != nil,
            controller.presentedViewController == nil
        else {
            guard retriesLeft > 0 else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + StoredRecordsNoticeConstants.retryDelay) { [weak self] in
                self?.presentNextStoredRecordsNotice(retriesLeft: retriesLeft - 1)
            }
            return
        }

        // The sheet closes before its action runs, so the next screen opens once it is gone.
        var followUp: (() -> Void)?
        let content = storedRecordsNoticeContent(for: notice) { followUp = $0 }
        let viewModel = SheetAlertPresentableViewModel(
            title: content.title,
            message: content.message,
            actions: content.actions,
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                self?.interactor.acknowledge(notice)
                self?.pendingStoredRecordsNotices.removeAll { $0 == notice }

                if let followUp {
                    followUp()
                } else {
                    self?.presentNextStoredRecordsNotice(
                        retriesLeft: StoredRecordsNoticeConstants.presentationRetries
                    )
                }
            },
            icon: R.image.iconWarningBig()
        )

        router.present(viewModel: viewModel, from: view)
    }

    /// Like the stored-record notices, it counts as shown only once the user has closed it;
    /// one that could not be presented stays pending for the next launch.
    func presentUpdateSecurityNotice(retriesLeft: Int) {
        guard
            let controller = view?.controller,
            controller.viewIfLoaded?.window != nil,
            controller.presentedViewController == nil
        else {
            guard retriesLeft > 0 else {
                finishUpdateSecurityNotice(acknowledged: false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + StoredRecordsNoticeConstants.retryDelay) { [weak self] in
                self?.presentUpdateSecurityNotice(retriesLeft: retriesLeft - 1)
            }
            return
        }

        let viewModel = SheetAlertPresentableViewModel.updateSecurityNotice(locale: selectedLocale) { [weak self] in
            self?.finishUpdateSecurityNotice(acknowledged: true)
        }

        router.present(viewModel: viewModel, from: view)
    }

    /// The last notice: universal accounts the wallet's password does not protect yet. Like
    /// the others it counts as shown once the user has closed it.
    func presentPasswordNotice(retriesLeft: Int) {
        guard !pendingPasswordNoticeAccounts.isEmpty else {
            presentOldAddressArrivals(retriesLeft: retriesLeft)
            return
        }
        guard
            let controller = view?.controller,
            controller.viewIfLoaded?.window != nil,
            controller.presentedViewController == nil
        else {
            guard retriesLeft > 0 else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + StoredRecordsNoticeConstants.retryDelay) { [weak self] in
                self?.presentPasswordNotice(retriesLeft: retriesLeft - 1)
            }
            return
        }

        let accounts = pendingPasswordNoticeAccounts
        pendingPasswordNoticeAccounts = []
        var followUp: (() -> Void)?
        let viewModel = UniversalWalletPasswordNotice.notice(
            for: accounts,
            locale: selectedLocale,
            onSwitch: { [weak self] in
                followUp = { self?.interactor.switchNoPasswordAccounts(accounts) }
            },
            onCopy: { [weak self] account in
                followUp = {
                    UIPasteboard.general.string = account.newAddress
                    self?.addressDidCopied()
                }
            },
            onDismiss: { [weak self] in
                self?.interactor.acknowledgeUniversalWalletPasswordNotice()
                followUp?()
            }
        )
        router.present(viewModel: viewModel, from: view)
    }

    /// Funds at an old address the wallet left; its password-protected account stays because it
    /// holds funds too or could not be checked.
    func presentOldAddressArrivals(retriesLeft: Int) {
        guard !pendingOldAddressArrivals.isEmpty else {
            return
        }
        guard
            let controller = view?.controller,
            controller.viewIfLoaded?.window != nil,
            controller.presentedViewController == nil
        else {
            guard retriesLeft > 0 else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + StoredRecordsNoticeConstants.retryDelay) { [weak self] in
                self?.presentOldAddressArrivals(retriesLeft: retriesLeft - 1)
            }
            return
        }

        let arrivals = pendingOldAddressArrivals
        pendingOldAddressArrivals = []
        let viewModel = UniversalWalletPasswordNotice.arrivals(arrivals, locale: selectedLocale) { [weak self] in
            self?.interactor.acknowledgeOldAddressArrivals(arrivals)
        }
        router.present(viewModel: viewModel, from: view)
    }

    func finishUpdateSecurityNotice(acknowledged: Bool) {
        if acknowledged {
            updateSecurityNotice.acknowledge()
        }
        isUpdateSecurityNoticeActive = false
        presentNextStoredRecordsNotice(retriesLeft: StoredRecordsNoticeConstants.presentationRetries)
    }

    func storedRecordsNoticeContent(
        for notice: StoredWalletRecordsNotice,
        onAction: @escaping (@escaping () -> Void) -> Void
    ) -> StoredRecordsNoticeContent {
        let languages = selectedLocale.rLanguages

        switch notice {
        case let .recordsNotShown(wallets, chainAccounts):
            let importAction = SheetAlertPresentableAction(
                title: R.string.localizable.importWallet(preferredLanguages: languages),
                style: .pinkBackgroundWhiteText
            ) { [weak self] in
                onAction {
                    self?.router.showImportWallet(defaultSource: .mnemonic, from: self?.view)
                }
            }

            return StoredRecordsNoticeContent(
                title: R.string.localizable.walletRecordsSheetTitle(preferredLanguages: languages),
                message: StoredWalletRecordsNoticeText.explanation(
                    wallets: wallets, chainAccounts: chainAccounts, locale: selectedLocale
                ),
                actions: [importAction, SheetAlertPresentableAction(title: RecoveryText.string("export"), style: .pinkBackgroundWhiteText) { [weak self] in
                    onAction { RetainedDataRestoreRouter.shared.showEmergencyMaterial(from: self?.view) }
                }]
            )
        case let .storedChainAccounts(walletIds, walletNames):
            var actions: [SheetAlertPresentableAction] = []
            if walletIds.contains(wallet.metaId) {
                let detailsAction = SheetAlertPresentableAction(
                    title: R.string.localizable.walletChainAccountsNoticeAction(preferredLanguages: languages),
                    style: .pinkBackgroundWhiteText
                ) { [weak self] in
                    onAction {
                        guard let self else { return }
                        self.router.showWalletDetails(from: self.view, wallet: self.wallet)
                    }
                }
                actions.append(detailsAction)
            }

            return StoredRecordsNoticeContent(
                title: R.string.localizable.walletChainAccountsNoticeTitle(preferredLanguages: languages),
                message: R.string.localizable.walletChainAccountsNoticeMessage(
                    walletNames.joined(separator: ", "), preferredLanguages: languages
                ),
                actions: actions
            )
        }
    }
}

// MARK: - Localizable

extension WalletMainContainerPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension WalletMainContainerPresenter: WalletMainContainerModuleInput {}

extension WalletMainContainerPresenter: WalletsManagmentModuleOutput {
    func showAddNewWallet() {
        router.showCreateNewWallet(from: view)
    }

    func showImportWallet(defaultSource: AccountImportSource) {
        router.showImportWallet(defaultSource: defaultSource, from: view)
    }

    func showImportGoogle() {
        router.showBackupSelectWallet(from: view)
    }

    func showGetPreinstalledWallet() {
        router.showGetPreinstalledWallet(from: view)
    }
}

// MARK: - ScanQRModuleOutput

extension WalletMainContainerPresenter: ScanQRModuleOutput {
    func didFinishWith(scanType: QRMatcherType) {
        switch scanType {
        case let .qrInfo(qrInfoType):
            router.showSendFlow(
                from: view,
                wallet: wallet,
                initialData: .init(qrInfoType: qrInfoType)
            )
        case let .walletConnect(uri):
            walletConnect(with: uri)
        }
    }
}
