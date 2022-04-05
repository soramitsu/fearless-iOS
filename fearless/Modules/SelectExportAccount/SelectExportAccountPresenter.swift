import Foundation
import SoraFoundation

final class SelectExportAccountPresenter {
    // MARK: Private properties

    private weak var view: SelectExportAccountViewInput?
    private let router: SelectExportAccountRouterInput
    private let interactor: SelectExportAccountInteractorInput
    private let viewModelFactory: SelectExportAccountViewModelFactoryProtocol
    private let metaAccount: MetaAccountModel

    private var nativeAccounts: [ChainAccountResponse]?
    private var addedAccounts: [ChainAccountModel]?
    private var chains: [ChainModel]?

    // MARK: - Constructors

    init(
        interactor: SelectExportAccountInteractorInput,
        router: SelectExportAccountRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: SelectExportAccountViewModelFactoryProtocol,
        metaAccount: MetaAccountModel
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.metaAccount = metaAccount
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideEmptyViewModel() {
        let viewModel = viewModelFactory.buildEmptyViewModel(
            metaAccount: metaAccount,
            locale: selectedLocale
        )

        view?.didReceive(state: .loading(viewModel: viewModel))
    }

    private func provideViewModel() {
        guard let chains = chains else {
            return
        }

        let viewModel = viewModelFactory.buildViewModel(
            metaAccount: metaAccount,
            nativeAccounts: chains.compactMap { metaAccount.fetch(for: $0.accountRequest()) },
            addedAccounts: Array(metaAccount.chainAccounts),
            chains: chains,
            locale: selectedLocale
        )

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

// MARK: - SelectExportAccountViewOutput

extension SelectExportAccountPresenter: SelectExportAccountViewOutput {
    func didLoad(view: SelectExportAccountViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideEmptyViewModel()
    }

    func exportNativeAccounts() {
        let chainAccountsInfo = chains?.compactMap { chain -> ChainAccountInfo? in
            guard let accountResponse = metaAccount.fetch(for: chain.accountRequest()) else {
                return nil
            }
            return ChainAccountInfo(
                chain: chain,
                account: accountResponse
            )
        }.compactMap { $0 }

        guard let chainAccountsInfo = chainAccountsInfo else { return }
        router.showWalletDetails(
            selectedWallet: metaAccount,
            accountsInfo: chainAccountsInfo,
            from: view
        )
    }
}

// MARK: - SelectExportAccountInteractorOutput

extension SelectExportAccountPresenter: SelectExportAccountInteractorOutput {
    func didReceive(chains: [ChainModel]) {
        self.chains = chains
        provideViewModel()
    }
}

// MARK: - Localizable

extension SelectExportAccountPresenter: Localizable {
    func applyLocalization() {}
}

extension SelectExportAccountPresenter: SelectExportAccountModuleInput {}
