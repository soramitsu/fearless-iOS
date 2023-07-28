import Foundation
import SoraFoundation
import SSFModels
import SSFCloudStorage

protocol BackupWalletViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol {
    func didReceive(viewModel: ProfileViewModelProtocol)
}

protocol BackupWalletInteractorInput: AnyObject {
    func setup(with output: BackupWalletInteractorOutput)
    func backup(
        substrate: ChainAccountInfo,
        ethereum: ChainAccountInfo,
        option: ExportOption
    )
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
            if backupAccounts.or([]).contains(where: { $0.address == wallet.substratePublicKey.toHex() }) {
                removeBackupFromGoogle()
            } else {
                startGoogleBackup(for: accounts)
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

    private func startGoogleBackup(for accounts: [ChainAccountInfo]) {
        guard
            let substrate = accounts.first(where: { $0.chain.chainBaseType == .substrate }),
            let ethereum = accounts.first(where: { $0.chain.isEthereumBased })
        else {
            return
        }

        if exportOptions.contains(.mnemonic) {
            interactor.backup(substrate: substrate, ethereum: ethereum, option: .mnemonic)
        } else if exportOptions.contains(.keystore) {
            interactor.backup(substrate: substrate, ethereum: ethereum, option: .keystore)
        } else if exportOptions.contains(.seed) {
            interactor.backup(substrate: substrate, ethereum: ethereum, option: .seed)
        }
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
}

// MARK: - BackupWalletViewOutput

extension BackupWalletPresenter: BackupWalletViewOutput {
    func viewDidAppear() {
        if backupIsCompleted {
            let text = R.string.localizable
                .backupWalletBackupGoogle(preferredLanguages: selectedLocale.rLanguages)
            router.presentSuccessNotification(text, from: view)
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
        guard
            indexPath.section == 1,
            let option = BackupWalletOptions(rawValue: indexPath.row)
        else {
            return
        }
        startBackup(with: option)
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
            backupAccounts?.removeAll(where: { $0.address == wallet.substratePublicKey.toHex() })
            provideViewModel()
        case let .failure(failure):
            let error = ConvenienceError(error: failure.localizedDescription)
            router.present(error: error, from: view, locale: selectedLocale)
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
            backupAccounts = []
            logger.error(failure.localizedDescription)
            let error = ConvenienceError(error: failure.localizedDescription)
            router.present(error: error, from: view, locale: selectedLocale)
        }
        provideViewModel()
    }

    func didReceive(request: BackupCreatePasswordFlow.RequestType) {
        router.showCreatePassword(wallet: wallet, request: request, from: view, moduleOutput: self)
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
