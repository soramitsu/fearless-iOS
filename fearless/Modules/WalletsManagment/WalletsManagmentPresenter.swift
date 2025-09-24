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

    private var featureToggleConfig = FeatureToggleConfig.defaultConfig

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

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveViewModels(viewModels)
        }
    }

    private func showImport() {
        let preferredLanguages = selectedLocale.rLanguages

        let mnemonicTitle = R.string.localizable
            .googleBackupChoiceMnemonic(preferredLanguages: preferredLanguages)
        let mnemonicAction = SheetAlertPresentableAction(
            title: mnemonicTitle,
            button: UIFactory.default.createDisabledButton()
        ) { [weak self] in
            self?.router.dissmis(view: self?.view) { [weak self] in
                self?.moduleOutput?.showImportWallet(defaultSource: .mnemonic)
            }
        }

        let rawTitle = R.string.localizable
            .googleBackupChoiceRaw(preferredLanguages: preferredLanguages)
        let rawAction = SheetAlertPresentableAction(
            title: rawTitle,
            button: UIFactory.default.createDisabledButton()
        ) { [weak self] in
            self?.router.dissmis(view: self?.view) { [weak self] in
                self?.moduleOutput?.showImportWallet(defaultSource: .seed)
            }
        }

        let jsonTitle = R.string.localizable
            .googleBackupChoiceJson(preferredLanguages: preferredLanguages)
        let jsonAction = SheetAlertPresentableAction(
            title: jsonTitle,
            button: UIFactory.default.createDisabledButton()
        ) { [weak self] in
            self?.router.dissmis(view: self?.view) { [weak self] in
                self?.moduleOutput?.showImportWallet(defaultSource: .keystore)
            }
        }

        let googleButton = TriangularedButton()
        googleButton.imageWithTitleView?.iconImage = R.image.googleBackup()
        googleButton.applyDisabledStyle()
        let googleTitle = R.string.localizable
            .googleBackupChoiceGoogle(preferredLanguages: preferredLanguages)
        let googleAction = SheetAlertPresentableAction(
            title: googleTitle,
            button: googleButton
        ) { [weak self] in
            self?.router.dissmis(view: self?.view) { [weak self] in
                self?.moduleOutput?.showImportGoogle()
            }
        }

        let preinstalledButton = TriangularedButton()
        preinstalledButton.imageWithTitleView?.iconImage = R.image.iconPreinstalledWallet()
        preinstalledButton.applyDisabledStyle()
        let preinstalledTitle = R.string.localizable
            .onboardingPreinstalledWalletButtonText(preferredLanguages: preferredLanguages)
        let preinstalledAction = SheetAlertPresentableAction(
            title: preinstalledTitle,
            button: preinstalledButton
        ) { [weak self] in
            self?.router.dissmis(view: self?.view) { [weak self] in
                self?.moduleOutput?.showGetPreinstalledWallet()
            }
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: preferredLanguages)
        let cancelAction = SheetAlertPresentableAction(
            title: cancelTitle,
            style: .pinkBackgroundWhiteText
        )

        var actions = [mnemonicAction, rawAction, jsonAction, googleAction]
        if featureToggleConfig.pendulumCaseEnabled == true {
            actions.append(preinstalledAction)
        }
        actions.append(cancelAction)
        let title = R.string.localizable
            .googleBackupChoiceTitle(preferredLanguages: preferredLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: nil,
            icon: nil
        )

        router.present(viewModel: viewModel, from: view)
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
        showImport()
    }

    func didLoad(view: WalletsManagmentViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didTapAccountScore(address: String?) {
        router.presentAccountScore(address: address, from: view)
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

    func didReceiveFeatureToggleConfig(result: Result<FeatureToggleConfig, Error>?) {
        switch result {
        case let .success(config):
            featureToggleConfig = config
        default:
            break
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
