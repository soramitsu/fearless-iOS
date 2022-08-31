import Foundation
import SoraFoundation

enum ChainIssue {
    case network(chains: [ChainModel])
    case missingAccount(chains: [ChainModel])
}

final class WalletMainContainerPresenter {
    // MARK: Private properties

    weak var assetListModuleInput: ChainAssetListModuleInput?
    private weak var view: WalletMainContainerViewInput?
    private let router: WalletMainContainerRouterInput
    private let interactor: WalletMainContainerInteractorInput

    private var selectedMetaAccount: MetaAccountModel
    private let viewModelFactory: WalletMainContainerViewModelFactoryProtocol

    // MARK: - State

    private var selectedChain: ChainModel?
    private var issues: [ChainIssue] = []
    private var chainsWithNetworkIssues: [ChainModel] = []
    private var missingAccounts: [ChainModel] = []

    // MARK: - Constructors

    init(
        selectedMetaAccount: MetaAccountModel,
        viewModelFactory: WalletMainContainerViewModelFactoryProtocol,
        interactor: WalletMainContainerInteractorInput,
        router: WalletMainContainerRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            selectedChain: selectedChain,
            selectedMetaAccount: selectedMetaAccount,
            chainsWithNetworkIssues: chainsWithNetworkIssues,
            missingAccounts: missingAccounts,
            locale: selectedLocale
        )

        view?.didReceiveViewModel(viewModel)
    }
}

// MARK: - WalletMainContainerViewOutput

extension WalletMainContainerPresenter: WalletMainContainerViewOutput {
    func didLoad(view: WalletMainContainerViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }

    func didTapOnSwitchWallet() {
        router.showWalletManagment(from: view, moduleOutput: self)
    }

    func didTapOnQR() {
//        router.showScanQr(from: view)
        ChainRegistryFacade.sharedRegistry.connected()
    }

    func didTapSearch() {
//        router.showSearch(from: view)
        ChainRegistryFacade.sharedRegistry.connect()
    }

    func didTapSelectNetwork() {
        router.showSelectNetwork(
            from: view,
            wallet: selectedMetaAccount,
            selectedChainId: selectedChain?.chainId,
            chainModels: nil,
            delegate: self
        )
    }

    func didTapOnBalance() {
        router.showSelectCurrency(
            from: view,
            wallet: selectedMetaAccount
        )
    }

    func didTapIssueButton() {
        let issues: [ChainIssue] = [
            .network(chains: chainsWithNetworkIssues),
            .missingAccount(chains: missingAccounts)
        ]
        router.showIssueNotification(
            from: view,
            issues: issues,
            wallet: selectedMetaAccount
        )
    }
}

// MARK: - WalletMainContainerInteractorOutput

extension WalletMainContainerPresenter: WalletMainContainerInteractorOutput {
    func didReceiceMissingAccounts(missingAccounts: [ChainModel]) {
        self.missingAccounts = missingAccounts
        provideViewModel()
    }

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
        selectedMetaAccount = account
        provideViewModel()
    }

    func didReceiveChainsWithNetworkIssues(_ chains: [ChainModel]) {
        chainsWithNetworkIssues = chains
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

extension WalletMainContainerPresenter: ChainAssetListModuleOutput {
    func didTapAction(actionType: SwipableCellButtonType, viewModel: ChainAccountBalanceCellViewModel) {
        switch actionType {
        case .send:
            router.showSendFlow(
                from: view,
                chainAsset: viewModel.chainAsset,
                selectedMetaAccount: selectedMetaAccount,
                transferFinishBlock: nil
            )
        case .receive:
            router.showReceiveFlow(
                from: view,
                chainAsset: viewModel.chainAsset,
                selectedMetaAccount: selectedMetaAccount
            )
        case .teleport:
            break
        case .hide:
            break
        }
    }
}
