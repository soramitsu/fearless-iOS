import Foundation
import SoraFoundation
import SSFUtils
import SSFModels

final class WalletMainContainerPresenter {
    // MARK: Private properties

    private weak var balanceInfoModuleInput: BalanceInfoModuleInput?
    private weak var assetListModuleInput: ChainAssetListModuleInput?
    private weak var view: WalletMainContainerViewInput?
    private let router: WalletMainContainerRouterInput
    private let interactor: WalletMainContainerInteractorInput

    private var wallet: MetaAccountModel
    private let viewModelFactory: WalletMainContainerViewModelFactoryProtocol
    private var chainSettings: [ChainSettings]?

    // MARK: - State

    private var selectedChain: ChainModel?
    private var issues: [ChainIssue] = []
    private var onceLoaded: Bool = false

    // MARK: - Constructors

    init(
        balanceInfoModuleInput: BalanceInfoModuleInput?,
        assetListModuleInput: ChainAssetListModuleInput?,
        wallet: MetaAccountModel,
        viewModelFactory: WalletMainContainerViewModelFactoryProtocol,
        interactor: WalletMainContainerInteractorInput,
        router: WalletMainContainerRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.balanceInfoModuleInput = balanceInfoModuleInput
        self.assetListModuleInput = assetListModuleInput
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            selectedChain: selectedChain,
            selectedMetaAccount: wallet,
            chainsIssues: issues,
            locale: selectedLocale,
            chainSettings: chainSettings ?? []
        )

        view?.didReceiveViewModel(viewModel)
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
            selectedChainId: selectedChain?.chainId,
            chainModels: nil,
            delegate: self
        )
    }

    func didTapOnBalance() {
        router.showSelectCurrency(
            from: view,
            wallet: wallet
        )
    }

    func didTapIssueButton() {
        router.showIssueNotification(
            from: view,
            issues: issues,
            wallet: wallet
        )
    }
}

// MARK: - WalletMainContainerInteractorOutput

extension WalletMainContainerPresenter: WalletMainContainerInteractorOutput {
    func didReceiveSelectedChain(_ chain: ChainModel?) {
        let needsReloadAssetsList: Bool = (chain?.chainId != selectedChain?.chainId) || !onceLoaded
        selectedChain = chain
        provideViewModel()

        guard needsReloadAssetsList else {
            return
        }

        var filters: [ChainAssetsFetching.Filter] = []
        if let filter: ChainAssetsFetching.Filter = chain.map({ chain in
            ChainAssetsFetching.Filter.chainId(chain.chainId)
        }) {
            filters.append(filter)
        }

        assetListModuleInput?.updateChainAssets(using: filters, sorts: [])

        onceLoaded = true
    }

    func didReceiveError(_ error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func didReceiveAccount(_ account: MetaAccountModel) {
        wallet = account
        provideViewModel()

        balanceInfoModuleInput?.replace(infoType: .wallet(wallet: account))
    }

    func didReceiveChainsIssues(chainsIssues: [ChainIssue]) {
        issues = chainsIssues
        provideViewModel()
    }

    func didReceive(chainSettings: [ChainSettings]) {
        self.chainSettings = chainSettings
        provideViewModel()
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

extension WalletMainContainerPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag _: Int?
    ) {
        interactor.saveChainIdForFilter(chain?.chainId)
    }
}

extension WalletMainContainerPresenter: ScanQRModuleOutput {
    func didFinishWithSolomon(soraAddress: String) {
        router.showSendFlow(
            from: view,
            wallet: wallet,
            initialData: .soraMainnet(address: soraAddress)
        )
    }

    func didFinishWith(address: String) {
        router.showSendFlow(
            from: view,
            wallet: wallet,
            initialData: .address(address)
        )
    }
}
