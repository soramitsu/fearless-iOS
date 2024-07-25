import Foundation
import SSFQRService
import SoraFoundation
import SSFUtils
import SSFModels

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

    // MARK: - Constructors

    init(
        balanceInfoModuleInput: BalanceInfoModuleInput?,
        assetListModuleInput: ChainAssetListModuleInput?,
        nftModuleInput: MainNftContainerModuleInput?,
        wallet: MetaAccountModel,
        viewModelFactory: WalletMainContainerViewModelFactoryProtocol,
        interactor: WalletMainContainerInteractorInput,
        router: WalletMainContainerRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.balanceInfoModuleInput = balanceInfoModuleInput
        self.assetListModuleInput = assetListModuleInput
        self.nftModuleInput = nftModuleInput
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router

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
                await MainActor.run(body: {
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
                    strongSelf.router.showMainStaking()
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
        case .preinstalledWallet:
            break
        }
    }
}
