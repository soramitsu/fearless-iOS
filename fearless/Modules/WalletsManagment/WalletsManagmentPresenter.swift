import Foundation
import SoraFoundation

final class WalletsManagmentPresenter {
    // MARK: Private properties

    private weak var view: WalletsManagmentViewInput?
    private let router: WalletsManagmentRouterInput
    private let interactor: WalletsManagmentInteractorInput
    private weak var moduleOutput: WalletsManagmentModuleOutput?
    private let contextTag: Int
    private let viewType: WalletsManagmentType

    private let viewModelFactory: WalletsManagmentViewModelFactoryProtocol
    private let logger: Logger

    private var wallets: [ManagedMetaAccountModel] = []
    private var balances: [MetaAccountId: WalletBalanceInfo] = [:]

    // MARK: - Constructors

    init(
        viewType: WalletsManagmentType,
        contextTag: Int,
        viewModelFactory: WalletsManagmentViewModelFactoryProtocol,
        logger: Logger,
        interactor: WalletsManagmentInteractorInput,
        router: WalletsManagmentRouterInput,
        moduleOutput: WalletsManagmentModuleOutput?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.viewType = viewType
        self.contextTag = contextTag
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.interactor = interactor
        self.router = router
        self.moduleOutput = moduleOutput
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModels = viewModelFactory.buildViewModel(
            viewType: viewType,
            from: wallets,
            balances: balances,
            locale: selectedLocale
        )

        view?.didReceiveViewModels(viewModels)
    }
}

// MARK: - WalletsManagmentViewOutput

extension WalletsManagmentPresenter: WalletsManagmentViewOutput {
    func didTap(on indexPath: IndexPath) {
        guard let wallet = wallets[safe: indexPath.row] else {
            return
        }

        moduleOutput?.selectedWallet(wallet.info, for: contextTag)
        interactor.select(wallet: wallet)
    }

    func didTapClose() {
        router.dissmis(view: view, dissmisCompletion: {})
    }

    func didTapOptions(for indexPath: IndexPath) {
        guard let wallet = wallets[safe: indexPath.row] else {
            return
        }
        router.showOptions(from: view, metaAccount: wallet, delegate: self)
    }

    func didTapNewWallet() {
        router.dissmis(view: view) { [weak self] in
            self?.moduleOutput?.showAddNewWallet()
        }
    }

    func didTapImportWallet() {
        router.dissmis(view: view) { [weak self] in
            self?.moduleOutput?.showImportWallet()
        }
    }

    func didLoad(view: WalletsManagmentViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - WalletsManagmentInteractorOutput

extension WalletsManagmentPresenter: WalletsManagmentInteractorOutput {
    func didReceive(error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func didCompleteSelection() {
        router.dissmis(view: view, dissmisCompletion: {})
    }

    func didReceiveWallets(_ wallets: Result<[ManagedMetaAccountModel], Error>) {
        switch wallets {
        case let .success(wallets):
            self.wallets = wallets
            DispatchQueue.main.async {
                self.provideViewModel()
            }
        case let .failure(error):
            logger.error("WalletsManagmentPresenter error: \(error.localizedDescription)")
        }
    }

    func didReceiveWalletBalances(_ balances: Result<[MetaAccountId: WalletBalanceInfo], Error>) {
        switch balances {
        case let .success(balances):
            self.balances = balances
            provideViewModel()
        case let .failure(error):
            logger.error("WalletsManagmentPresenter error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Localizable

extension WalletsManagmentPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension WalletsManagmentPresenter: WalletsManagmentModuleInput {}

// MARK: - WalletOptionModuleOutput

extension WalletsManagmentPresenter: WalletOptionModuleOutput {
    func walletWasRemoved() {
        interactor.fetchWalletsFromRepo()
    }
}
