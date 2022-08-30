import Foundation
import SoraFoundation

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
            chainsIssues: issues,
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
        router.showScanQr(from: view)
    }

    func didTapSearch() {
        router.showSearch(from: view)
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
        router.showIssueNotification(
            from: view,
            issues: issues,
            wallet: selectedMetaAccount
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
        selectedMetaAccount = account
        provideViewModel()
    }

    func didReceiveChainsIssues(chainsIssues: [ChainIssue]) {
        issues = chainsIssues
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
        guard let chainId = chain?.chainId else {
            assetListModuleInput?.updateChainAssets(using: [], sorts: [])
            return
        }
        assetListModuleInput?.updateChainAssets(using: [.chainId(chainId)], sorts: [])
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
