import Foundation
import SSFModels
import SoraFoundation

protocol DappBrowserViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: [DappBrowserViewModel])
    func didReceive(walletName: String)
    func didReceive(viewModel: DappBrowsetNetworkFilterViewModel?)
}

protocol DappBrowserInteractorInput: AnyObject {
    var connectedApps: [TonConnectApp] { get async throws }
    var chains: [ChainModel] { get async throws }
    var filter: NetworkManagmentFilter { get set }
    func setup(with output: DappBrowserInteractorOutput)
}

final class DappBrowserPresenter {
    // MARK: Private properties

    private weak var view: DappBrowserViewInput?
    private let router: DappBrowserRouterInput
    private let interactor: DappBrowserInteractorInput
    private let logger: LoggerProtocol
    private let viewModelFactory: DappBrowserViewModelFactory
    private var wallet: MetaAccountModel

    private var dapps: [DappCategory]?
    private var page: DappBrowserViewControllerPage = .dapps

    // MARK: - Constructors

    init(
        interactor: DappBrowserInteractorInput,
        router: DappBrowserRouterInput,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol,
        viewModelFactory: DappBrowserViewModelFactory,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideTableViewModel() {
        guard let dapps else {
            return
        }
        Task {
            let viewModel = viewModelFactory.buildViewModel(
                dapps: dapps,
                connected: try await interactor.connectedApps,
                chains: try await interactor.chains,
                networkFilter: interactor.filter,
                locale: selectedLocale,
                wallet: wallet,
                page: page
            )
            Task { @MainActor in
                view?.didReceive(viewModel: viewModel)
            }
        }
    }

    private func provideWalletViewModel() {
        Task { @MainActor in
            view?.didReceive(walletName: wallet.name)
        }
    }

    private func provideNetworkViewModel() {
        Task {
            let viewModel = viewModelFactory.buildNetworkFilterViewModel(
                chains: try await interactor.chains,
                filter: interactor.filter,
                locale: selectedLocale
            )
            Task { @MainActor in
                view?.didReceive(viewModel: viewModel)
            }
        }
    }

    private func observTonConnect() {
        Task {
            await ServiceAssembly.shared.tonConnectService().set(listener: self)
        }
    }
}

// MARK: - DappBrowserViewOutput

extension DappBrowserPresenter: DappBrowserViewOutput {
    func didTapSearchButton() {
        Task {
            var appsForSearch: [TonDapp] = dapps.or([])
                .map { $0.apps }
                .reduce([], +)
                .uniq(predicate: { $0 })
            switch page {
            case .dapps:
                break
            case .connected:
                let connectedApps = try await interactor.connectedApps
                appsForSearch = appsForSearch.filter { app in
                    connectedApps.contains(where: { $0.appUrl.host == app.url.host })
                }
            }
            Task { @MainActor [appsForSearch] in
                let title = R.string.localizable.commonSearch(preferredLanguages: selectedLocale.rLanguages)
                router.showList(
                    from: view,
                    dapps: appsForSearch,
                    title: title,
                    wallet: wallet
                )
            }
        }
    }

    func didSelect(page: DappBrowserViewControllerPage) {
        self.page = page
        provideTableViewModel()
    }

    func didSelect(dapp: TonDapp) {
        router.showDapp(from: view, dapp: dapp, wallet: wallet, moduleOutput: self)
    }

    func didTapOnWalletSelectButton() {
        router.showWalletManagment(
            from: view,
            moduleOutput: self
        )
    }

    func didTapOnNetworkSelectButton() {
        Task {
            let allChains = try await interactor.chains
            let hasDappChains = allChains.filter { chainModel in
                dapps.or([]).contains { dappCat in
                    dappCat.apps.contains { dapp in
                        dapp.chains.contains(chainModel.chainId)
                    }
                }
            }
            Task { @MainActor in
                router.showSelectNetwork(
                    from: view,
                    wallet: wallet,
                    chains: hasDappChains,
                    delegate: self,
                    initialFilter: interactor.filter
                )
            }
        }
    }

    func didTapOnSection(with dapps: [TonDapp], title: String) {
        let all = R.string.localizable.stakingAnalyticsPeriodAll(
            preferredLanguages: selectedLocale.rLanguages
        )
        router.showList(
            from: view,
            dapps: dapps,
            title: [all, title].joined(separator: " "),
            wallet: wallet
        )
    }

    func didLoad(view: DappBrowserViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideWalletViewModel()
        provideNetworkViewModel()
        observTonConnect()
    }
}

// MARK: - DappBrowserInteractorOutput

extension DappBrowserPresenter: DappBrowserInteractorOutput {
    func didReceive(dapps: Result<[DappCategory], any Error>) {
        switch dapps {
        case let .success(dapps):
            self.dapps = dapps
            provideTableViewModel()
            provideNetworkViewModel()
        case let .failure(error):
            logger.customError(error)
        }
    }

    func didUpdate(wallet: MetaAccountModel) {
        self.wallet = wallet
        provideWalletViewModel()
    }
}

// MARK: - Localizable

extension DappBrowserPresenter: Localizable {
    func applyLocalization() {}
}

extension DappBrowserPresenter: DappBrowserModuleInput {}

// MARK: - WalletsManagmentModuleOutput

extension DappBrowserPresenter: WalletsManagmentModuleOutput {
    func selectedWallet(_ wallet: MetaAccountModel, for contextTag: Int) {
        self.wallet = wallet
        provideWalletViewModel()
    }

    func showAddNewWallet() {
        router.showCreateNewWallet(ecosystem: nil, from: view)
    }
}

// MARK: - NetworkManagmentModuleOutput

extension DappBrowserPresenter: NetworkManagmentModuleOutput {
    func did(select: NetworkManagmentFilter, contextTag: Int?) {
        interactor.filter = select
        provideTableViewModel()
        provideNetworkViewModel()
    }
}

// MARK: - TonWebBridgeModuleOutput

extension DappBrowserPresenter: TonWebBridgeModuleOutput {
    func didDisconnect() {
        provideTableViewModel()
    }
}

// MARK: - TonConnectServiceDelegate

extension DappBrowserPresenter: TonConnectServiceDelegate {
    func didDisconnectedApp() {
        provideTableViewModel()
    }
}
