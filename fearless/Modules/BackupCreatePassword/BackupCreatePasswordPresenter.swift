import Foundation
import SoraFoundation
import SSFCloudStorage
import SSFModels

protocol BackupCreatePasswordViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)
    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol)
    func setPassword(isMatched: Bool)
}

protocol BackupCreatePasswordInteractorInput: AnyObject {
    func setup(with output: BackupCreatePasswordInteractorOutput)
    func createAndBackupAccount(password: String)
    func hasPincode() -> Bool
}

final class BackupCreatePasswordPresenter {
    // MARK: Private properties

    private weak var view: BackupCreatePasswordViewInput?
    private let router: BackupCreatePasswordRouterInput
    private let interactor: BackupCreatePasswordInteractorInput
    private let logger: LoggerProtocol

    private let flow: BackupCreatePasswordFlow
    private weak var moduleOutput: BackupCreatePasswordModuleOutput?

    private let passwordInputViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.backupPassword))
    }()

    private let confirmationViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    // MARK: - Constructors

    init(
        logger: LoggerProtocol,
        flow: BackupCreatePasswordFlow,
        moduleOutput: BackupCreatePasswordModuleOutput?,
        interactor: BackupCreatePasswordInteractorInput,
        router: BackupCreatePasswordRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.logger = logger
        self.flow = flow
        self.moduleOutput = moduleOutput
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func proceed() {
        let password = passwordInputViewModel.inputHandler.normalizedValue

        guard password == confirmationViewModel.inputHandler.normalizedValue else {
            view?.setPassword(isMatched: false)
            return
        }

        interactor.createAndBackupAccount(password: password)
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
            self?.proceed()
        }
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [retryAction],
            closeAction: nil,
            dismissCompletion: { [weak self] in
                self?.view?.didStopLoading()
            }
        )
        router.present(
            viewModel: viewModel,
            from: view
        )
    }

    /// Signing in again cannot change what the wallet's stored keys allow, so these errors say
    /// what happened and lead back to the other backup options instead of offering a retry.
    private func showBackupNotCreated(message: String, canRetry: Bool) {
        let languages = selectedLocale.rLanguages
        var actions: [SheetAlertPresentableAction] = []
        if canRetry {
            actions.append(SheetAlertPresentableAction(
                title: R.string.localizable.tryAgain(preferredLanguages: languages),
                style: .pinkBackgroundWhiteText,
                button: UIFactory.default.createMainActionButton()
            ) { [weak self] in
                self?.view?.didStartLoading()
                self?.proceed()
            })
        } else {
            actions.append(SheetAlertPresentableAction(
                title: R.string.localizable.commonClose(preferredLanguages: languages),
                style: .pinkBackgroundWhiteText,
                button: UIFactory.default.createMainActionButton()
            ) { [weak self] in
                self?.router.pop(from: self?.view)
            })
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.backupGoogleNotCreatedTitle(preferredLanguages: languages),
            message: message,
            actions: actions,
            closeAction: canRetry ? R.string.localizable.commonClose(preferredLanguages: languages) : nil
        )
        router.present(viewModel: viewModel, from: view)
    }

    private func finishWalletBackup() {
        moduleOutput?.backupDidComplete()
        router.pop(from: view)
    }

    /// The backup restores the wallet's Substrate and Ethereum accounts; before the wallet is
    /// shown as backed up, say which of its other accounts it does not give back.
    private func showAccountsNotRestored(_ accounts: [ChainAccountModel]) {
        let languages = selectedLocale.rLanguages
        let accountList = accounts.map(GoogleDriveBackupContent.displayLine(for:)).joined(separator: "\n")
        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.backupGooglePartialTitle(preferredLanguages: languages),
            message: R.string.localizable.backupGooglePartialMessage(accountList, preferredLanguages: languages),
            actions: [],
            closeAction: R.string.localizable.commonOk(preferredLanguages: languages),
            dismissCompletion: { [weak self] in
                self?.finishWalletBackup()
            }
        )
        router.present(viewModel: viewModel, from: view)
    }

    private func show(error: Error) {
        let languages = selectedLocale.rLanguages

        switch error {
        case BackupCreatePasswordError.nativeTonWalletNotSupported:
            showBackupNotCreated(
                message: R.string.localizable.backupGoogleTonUnsupportedMessage(preferredLanguages: languages),
                canRetry: false
            )
        case BackupCreatePasswordError.walletWithoutSubstrateAccount:
            showBackupNotCreated(
                message: R.string.localizable.backupGoogleSubstrateUnsupportedMessage(preferredLanguages: languages),
                canRetry: false
            )
        case BackupCreatePasswordError.incompleteBackupMaterial,
             BackupCreatePasswordError.unverifiedRecoveryPhrase:
            showBackupNotCreated(
                message: R.string.localizable.backupGoogleMaterialMessage(preferredLanguages: languages),
                canRetry: false
            )
        case BackupCreatePasswordError.cloudBackupReadbackMismatch,
             CloudStorageServiceError.readbackMismatch,
             CloudStorageServiceError.incorectJson,
             CloudStorageServiceError.incorectPassword:
            showBackupNotCreated(
                message: R.string.localizable.backupGoogleReadbackMessage(preferredLanguages: languages),
                canRetry: true
            )
        default:
            showGoogleIssueAlert()
        }
    }
}

// MARK: - BackupCreatePasswordViewOutput

extension BackupCreatePasswordPresenter: BackupCreatePasswordViewOutput {
    func didTapBackButton() {
        router.pop(from: view)
    }

    func didTapContinueButton() {
        view?.didStartLoading()
        proceed()
    }

    func didLoad(view: BackupCreatePasswordViewInput) {
        self.view = view
        interactor.setup(with: self)
        view.setPasswordInputViewModel(passwordInputViewModel)
        view.setPasswordConfirmationViewModel(confirmationViewModel)
    }
}

// MARK: - BackupCreatePasswordInteractorOutput

extension BackupCreatePasswordPresenter: BackupCreatePasswordInteractorOutput {
    func didReceive(error: Error) {
        logger.customError(error)
        DispatchQueue.main.async {
            self.view?.didStopLoading()
            self.show(error: error)
        }
    }

    func didComplete(accountsNotRestored: [ChainAccountModel]) {
        view?.didStopLoading()
        switch flow {
        case .createWallet:
            if interactor.hasPincode() {
                router.dismiss(from: view)
            } else {
                router.showPinSetup()
            }
        case .backupWallet:
            guard accountsNotRestored.isNotEmpty else {
                finishWalletBackup()
                return
            }
            showAccountsNotRestored(accountsNotRestored)
        }
    }
}

// MARK: - Localizable

extension BackupCreatePasswordPresenter: Localizable {
    func applyLocalization() {}
}

extension BackupCreatePasswordPresenter: BackupCreatePasswordModuleInput {}
