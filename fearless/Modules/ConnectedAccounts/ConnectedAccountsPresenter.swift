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
    private var wallet: MetaAccountModel
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
    
    private func startAddAccountFlow(chains: [ChainModel]) {
        func showCreateFlow() {
            let rLanguages = localizationManager?.selectedLocale.rLanguages
            let actionTitle = R.string.localizable.commonOk(preferredLanguages: rLanguages)
            let action = SheetAlertPresentableAction(title: actionTitle) { [weak self] in
                guard let self else { return }
                self.router.showCreate(
                    wallet: self.wallet,
                    chains: chains,
                    from: self.view
                )
            }

            let title = R.string.localizable.commonNoScreenshotTitle(preferredLanguages: rLanguages)
            let message = R.string.localizable.commonNoScreenshotMessage(preferredLanguages: rLanguages)
            let viewModel = SheetAlertPresentableViewModel(
                title: title,
                message: message,
                actions: [action],
                closeAction: nil,
                icon: R.image.iconWarningBig()
            )

            router.present(viewModel: viewModel, from: view)
        }

        let options: [ReplaceChainOption] = ReplaceChainOption.allCases
        router.showUniqueChainSourceSelection(
            from: view,
            items: options,
            callback: {
                [weak self] selectedIndex in
                let option = options[selectedIndex]
                switch option {
                case .create:
                    showCreateFlow()
                case .import:
                    guard let wallet = self?.wallet else {
                        return
                    }
                    let uniqueChainModels = chains.map {
                        UniqueChainModel(
                            meta: wallet,
                            chain: $0
                        )
                    }
                    self?.showImportSource(for: chains)
                }
            }
        )
    }
    
    private func showImportSource(for chains: [ChainModel]) {
        let preferredLanguages = selectedLocale.rLanguages

        let mnemonicTitle = R.string.localizable
            .googleBackupChoiceMnemonic(preferredLanguages: preferredLanguages)
        let mnemonicAction = SheetAlertPresentableAction(
            title: mnemonicTitle,
            button: UIFactory.default.createDisabledButton()
        ) { [weak self] in
            guard let self = self else { return }
            self.router.showImport(wallet: wallet, chains: chains, defaultSource: .mnemonic, from: view)
        }

        let rawTitle = R.string.localizable
            .googleBackupChoiceRaw(preferredLanguages: preferredLanguages)
        let rawAction = SheetAlertPresentableAction(
            title: rawTitle,
            button: UIFactory.default.createDisabledButton()
        ) { [weak self] in
            guard let self = self else { return }
            self.router.showImport(wallet: wallet, chains: chains, defaultSource: .seed, from: view)
        }

        let jsonTitle = R.string.localizable
            .googleBackupChoiceJson(preferredLanguages: preferredLanguages)
        let jsonAction = SheetAlertPresentableAction(
            title: jsonTitle,
            button: UIFactory.default.createDisabledButton()
        ) { [weak self] in
            guard let self = self else { return }
            self.router.showImport(wallet: wallet, chains: chains, defaultSource: .keystore, from: view)
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: preferredLanguages)
        let cancelAction = SheetAlertPresentableAction(
            title: cancelTitle,
            style: .pinkBackgroundWhiteText
        )

        let title = R.string.localizable
            .googleBackupChoiceTitle(preferredLanguages: preferredLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [mnemonicAction, rawAction, jsonAction, cancelAction],
            closeAction: nil,
            icon: nil
        )

        router.present(viewModel: viewModel, from: view)
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
            startAddAccountFlow(chains: viewModel.chains)
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
    func processSelectedAccountChanged(wallet: SSFModels.MetaAccountModel) {
        self.wallet = wallet
        provideViewModel()
    }
    
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
