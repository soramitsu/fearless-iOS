import Foundation
import SSFModels
import SoraFoundation

@MainActor
protocol ConnectedAccountsViewInput: ControllerBackedProtocol {
    func didReceive(viewModels: [ConnectedAccountsViewModel])
}

protocol ConnectedAccountsInteractorInput: AnyObject {
    func setup(with output: ConnectedAccountsInteractorOutput)
    var chains: [ChainModel] { get async throws }
}

final class ConnectedAccountsPresenter {
    // MARK: Private properties
    private weak var view: ConnectedAccountsViewInput?
    private let router: ConnectedAccountsRouterInput
    private let interactor: ConnectedAccountsInteractorInput
    private let viewModelFactory: ConnectedAccountsViewModelFactory
    private let wallet: MetaAccountModel
    private lazy var logger: LoggerProtocol = Logger.shared

    private var balance: WalletBalanceInfo?

    // MARK: - Constructors
    init(
        wallet: MetaAccountModel,
        viewModelFactory: ConnectedAccountsViewModelFactory,
        interactor: ConnectedAccountsInteractorInput,
        router: ConnectedAccountsRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        Task {
            let viewModel = viewModelFactory.buildViewModel(
                wallet: wallet,
                balance: balance,
                chains: try await interactor.chains,
                locale: selectedLocale
            )
            await view?.didReceive(viewModels: viewModel)
        }
    }
}

// MARK: - ConnectedAccountsViewOutput
extension ConnectedAccountsPresenter: ConnectedAccountsViewOutput {
    func activateAccountDetails() {
        switch wallet.ecosystem {
        case .regular:
            router.showAccountDetails(from: view, metaAccount: wallet)
        case .ton:
            break
        }
    }

    func didTapAccountScore(address: String?) {
        router.presentAccountScore(address: address, from: view)

    }

    func didSelect(viewModel: ConnectedAccountsViewModel.Accounts) {
        guard viewModel.count > 0 else {
            // TODO: - Show Add account flow
            return
        }
        router.showOptions(
            from: view,
            ecosystem: viewModel.ecosystem,
            wallet: wallet,
            chains: viewModel.chains,
            moduleOutput: self
        )
    }

    func dismiss() {
        router.dismiss(view: view)
    }

    func pop() {
        router.dismiss(view: view)
    }

    func didLoad(view: ConnectedAccountsViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }
}

// MARK: - ConnectedAccountsInteractorOutput
extension ConnectedAccountsPresenter: ConnectedAccountsInteractorOutput {
    func didReceiveWalletBalances(_ balances: Result<[MetaAccountId: WalletBalanceInfo], any Error>) {
        switch balances {
        case let .success(balances):
            balance = balances[wallet.metaId]
            provideViewModel()
        case let .failure(error):
            logger.error("WalletsManagmentPresenter error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Localizable
extension ConnectedAccountsPresenter: Localizable {
    func applyLocalization() {}
}

extension ConnectedAccountsPresenter: ConnectedAccountsModuleInput {}

// MARK: - EcosystemOptionsModuleOutput
extension ConnectedAccountsPresenter: EcosystemOptionsModuleOutput {
    func showMnemonicExport(flow: ExportFlow) {
        router.showMnemonicExport(
            flow: flow,
            from: view
        )
    }

    func showKeystoreExport(flow: ExportFlow) {
        router.showKeystoreExport(
            flow: flow,
            from: view
        )
    }

    func showSeedExport(flow: ExportFlow) {
        router.showSeedExport(
            flow: flow,
            from: view
        )
    }

    func showWalletDetails(chains: [ChainModel]?) {
        router.showWalletDetails(
            view: view,
            wallet: wallet,
            chains: chains
        )
    }
}
