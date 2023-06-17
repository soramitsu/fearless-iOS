import Foundation
import SoraFoundation
import SSFUtils

final class WalletMainContainerPresenter {
    // MARK: Private properties

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

    // MARK: - Constructors

    init(
        assetListModuleInput: ChainAssetListModuleInput?,
        wallet: MetaAccountModel,
        viewModelFactory: WalletMainContainerViewModelFactoryProtocol,
        interactor: WalletMainContainerInteractorInput,
        router: WalletMainContainerRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
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
//        router.showScanQr(from: view, moduleOutput: self)
        interactor.testSaveOldAccountInfo()
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
        selectedChain = chain
        provideViewModel()
        guard let chainId = chain?.chainId else {
            assetListModuleInput?.updateChainAssets(using: [], sorts: [])
            return
        }
        assetListModuleInput?.updateChainAssets(using: [.chainId(chainId)], sorts: [])
    }

    func didReceiveError(_ error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func didReceiveAccount(_ account: MetaAccountModel) {
        wallet = account
        provideViewModel()
    }

    func didReceiveChainsIssues(chainsIssues: [ChainIssue]) {
        issues = chainsIssues
        provideViewModel()
    }

    func didReceive(chainSettings: [ChainSettings]) {
        self.chainSettings = chainSettings
        provideViewModel()
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

    func showImportWallet() {
        router.showImportWallet(from: view)
    }
}

extension WalletMainContainerPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?
    ) {
        interactor.saveChainIdForFilter(chain?.chainId)
    }
}

extension WalletMainContainerPresenter: ScanQRModuleOutput {
    func didFinishWith(address: String) {
        router.showSendFlow(
            from: view,
            wallet: wallet,
            address: address
        )
    }
}
