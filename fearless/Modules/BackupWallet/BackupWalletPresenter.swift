import Foundation
import SoraFoundation
import SSFModels
import SSFCloudStorage

protocol BackupWalletViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol {
    func didReceive(viewModel: ProfileViewModelProtocol)
}

protocol BackupWalletInteractorInput: AnyObject {
    func setup(with output: BackupWalletInteractorOutput)
    func removeBackupFromGoogle()
    func viewDidAppear()
}

final class BackupWalletPresenter {
    // MARK: Private properties

    private weak var view: BackupWalletViewInput?
    private let router: BackupWalletRouterInput
    private let interactor: BackupWalletInteractorInput

    private let logger: LoggerProtocol
    private let wallet: MetaAccountModel
    private lazy var viewModelFactory: BackupWalletViewModelFactoryProtocol = {
        BackupWalletViewModelFactory()
    }()

    private var balanceInfo: WalletBalanceInfo?
    private var chains: [ChainModel] = []
    private var exportOptions: [ExportOption] = []
    private var backupAccounts: [OpenBackupAccount]?
    private var googleAuthorized = false
    private var backupIsCompleted = false
    private var replacedAccountAlertDidShown = false
    private var runWalletDetailsFlow = false

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        interactor: BackupWalletInteractorInput,
        router: BackupWalletRouterInput,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            from: wallet,
            locale: selectedLocale,
            balance: balanceInfo,
            exportOptions: exportOptions,
            backupAccounts: backupAccounts
        )
        DispatchQueue.main.async {
            self.view?.didReceive(viewModel: viewModel)
        }
    }

    private func startBackup(with option: BackupWalletOptions) {
        let accounts = prepareChainAccountInfos()
        let flow: ExportFlow = .multiple(wallet: wallet, accounts: accounts)
        switch option {
        case .phrase:
            router.showMnemonicExport(flow: flow, from: view)
        case .seed:
            router.showSeedExport(flow: flow, from: view)
        case .json:
            router.showKeystoreExport(flow: flow, from: view)
        case .backupGoogle, .removeGoogle:
            let address42 = try? wallet.substratePublicKey.toAddress(using: .substrate(42))
            if backupAccounts.or([]).contains(where: { $0.address == address42 }) {
                removeBackupFromGoogle()
            } else {
                router.showCreatePassword(
                    wallet: wallet,
                    accounts: accounts,
                    options: exportOptions,
                    from: view,
                    moduleOutput: self
                )
            }
        }
    }

    private func prepareChainAccountInfos() -> [ChainAccountInfo] {
        let chainAccountsInfo = chains.compactMap { chain -> ChainAccountInfo? in
            guard let accountResponse = wallet.fetch(for: chain.accountRequest()), !accountResponse.isChainAccount else {
                return nil
            }
            return ChainAccountInfo(
                chain: chain,
                account: accountResponse
            )
        }.compactMap { $0 }
        return chainAccountsInfo
    }

    private func removeBackupFromGoogle() {
        let closeActionTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)
        let closeAction = SheetAlertPresentableAction(title: closeActionTitle)

        let delecteActionTitle = R.string.localizable
            .connectionDeleteConfirm(preferredLanguages: selectedLocale.rLanguages)
        let deleteAction = SheetAlertPresentableAction(
            title: delecteActionTitle,
            style: .pinkBackgroundWhiteText,
            button: UIFactory.default.createMainActionButton()
        ) { [weak self] in
            self?.view?.didStartLoading()
            self?.interactor.removeBackupFromGoogle()
        }
        let action = [closeAction, deleteAction]
        let alertTitle = R.string.localizable
            .commonConfirmTitle(preferredLanguages: selectedLocale.rLanguages)
        let alertMessage = R.string.localizable
            .backupWalletDeleteMessage(preferredLanguages: selectedLocale.rLanguages)
        let alertViewModel = SheetAlertPresentableViewModel(
            title: alertTitle,
            message: alertMessage,
            actions: action,
            closeAction: nil,
            actionAxis: .horizontal
        )
        router.present(viewModel: alertViewModel, from: view)
    }

    private func showGoogleIssueAlert() {
        let title = R.string.localizable
            .noAccessToGoogle(preferredLanguages: selectedLocale.rLanguages)
        let retryTitle = R.string.localizable
            .tryAgain(preferredLanguages: selectedLocale.rLanguages)
        let retryAction = SheetAlertPresentableAction(
            title: retryTitle,
            style: .pinkBackgroundWhiteText,
            button: UIFactory.default.createMainActionButton()
        ) { [weak self] in
            self?.interactor.viewDidAppear()
        }
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [retryAction],
            closeAction: nil,
            dismissCompletion: { [weak self] in
                self?.googleAuthorized = true
            }
        )
        router.present(
            viewModel: viewModel,
            from: view
        )
    }

    private func showDelete(error: Error) {
        let presentingError: ConvenienceError
        if let error = error as? FearlessCompatibilityError {
            switch error {
            case .cantRemoveExtensionBackup:
                let message = R.string.localizable
                    .removeBackupExtensionErrorMessage(preferredLanguages: selectedLocale.rLanguages)
                presentingError = ConvenienceError(error: message)
            case .backupNotFound:
                presentingError = ConvenienceError(error: error.localizedDescription)
            }
        } else {
            presentingError = ConvenienceError(error: error.localizedDescription)
        }
        router.present(error: presentingError, from: view, locale: selectedLocale)
    }

    private func showReplacedAccountAlert() {
        let message: String
        if wallet.chainAccounts.count == 1,
           let chainAccount = wallet.chainAccounts.first,
           let chain = chains.first(where: { $0.chainId == chainAccount.chainId }),
           let address = try? chainAccount.accountId.toAddress(using: chain.chainFormat) {
            message = R.string.localizable
                .backupWalletReplaceAccountsAlert(chain.name, address, preferredLanguages: selectedLocale.rLanguages)
        } else {
            message = R.string.localizable
                .backupWalletReplaceSeveralAlert(preferredLanguages: selectedLocale.rLanguages)
        }

        let walletDetailsActions = SheetAlertPresentableAction(
            title: R.string.localizable.backupChainAccount(preferredLanguages: selectedLocale.rLanguages),
            style: .pinkBackgroundWhiteText,
            button: UIFactory.default.createMainActionButton()
        ) { [weak self] in
            guard let self = self else { return }
            self.runWalletDetailsFlow = true
            self.showReplacedAccountScreen()
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
            message: message,
            actions: [walletDetailsActions],
            closeAction: nil,
            dismissCompletion: { [weak self] in
                self?.replacedAccountAlertDidShown = true
                guard self?.runWalletDetailsFlow == false else {
                    return
                }
                self?.viewDidAppear()
            }
        )
        router.present(
            viewModel: viewModel,
            from: view
        )
    }

    private func showReplacedAccountScreen() {
        router.showWalletDetails(
            wallet: wallet,
            from: view
        )
    }
}

// MARK: - BackupWalletViewOutput

extension BackupWalletPresenter: BackupWalletViewOutput {
    func viewDidAppear() {
        if backupIsCompleted {
            let text = R.string.localizable
                .backupWalletBackupGoogle(preferredLanguages: selectedLocale.rLanguages)
            router.presentSuccessNotification(text, from: view)
            backupIsCompleted = false
        }
        if wallet.chainAccounts.isNotEmpty, !googleAuthorized, !replacedAccountAlertDidShown {
            showReplacedAccountAlert()
            return
        }
        guard !googleAuthorized else {
            return
        }
        view?.didStartLoading()
        interactor.viewDidAppear()
    }

    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func didSelectRowAt(_ indexPath: IndexPath) {
        guard indexPath.section == 1 else {
            return
        }
        if
            let exportOption = exportOptions[safe: indexPath.row] {
            let backupOptions = BackupWalletOptions(exportOptions: exportOption)
            startBackup(with: backupOptions)
        } else {
            startBackup(with: .backupGoogle)
        }
    }

    func didLoad(view: BackupWalletViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }
}

// MARK: - BackupWalletInteractorOutput

extension BackupWalletPresenter: BackupWalletInteractorOutput {
    func didReceiveRemove(result: Result<Void, Error>) {
        view?.didStopLoading()
        switch result {
        case .success:
            let text = R.string.localizable
                .commonDone(preferredLanguages: selectedLocale.rLanguages)
            router.presentSuccessNotification(text, from: view)

            let address42 = try? wallet.substratePublicKey.toAddress(using: .substrate(42))
            backupAccounts?.removeAll(where: { $0.address == address42 })
            provideViewModel()
        case let .failure(failure):
            showDelete(error: failure)
        }
    }

    func didReceiveBackupAccounts(result: Result<[SSFCloudStorage.OpenBackupAccount], Error>) {
        view?.didStopLoading()
        switch result {
        case let .success(accounts):
            googleAuthorized = true
            backupAccounts = accounts
        case let .failure(failure):
            googleAuthorized = false
            backupAccounts = nil
            logger.error(failure.localizedDescription)
            showGoogleIssueAlert()
        }
        provideViewModel()
    }

    func didReceive(error: Error) {
        logger.customError(error)
    }

    func didReceive(chains: [SSFModels.ChainModel]) {
        self.chains = chains
    }

    func didReceive(options: [ExportOption]) {
        exportOptions = options
        provideViewModel()
    }

    func didReceiveBalances(result: WalletBalancesResult) {
        switch result {
        case let .success(balanceInfos):
            balanceInfo = balanceInfos[wallet.identifier]
            provideViewModel()
        case let .failure(error):
            logger.customError(error)
        }
    }
}

// MARK: - Localizable

extension BackupWalletPresenter: Localizable {
    func applyLocalization() {}
}

// MARK: - BackupCreatePasswordModuleOutput

extension BackupWalletPresenter: BackupCreatePasswordModuleOutput {
    func backupDidComplete() {
        backupIsCompleted = true
        interactor.viewDidAppear()
    }
}

extension BackupWalletPresenter: BackupWalletModuleInput {}
