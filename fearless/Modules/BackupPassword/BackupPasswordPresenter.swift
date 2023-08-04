import Foundation
import SoraFoundation
import SSFCloudStorage

protocol BackupPasswordViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol {
    func didReceive(walletName: String)
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)
}

protocol BackupPasswordInteractorInput: AccountImportInteractorInputProtocol {
    func setup(with output: BackupPasswordInteractorOutput)
    func importBackup(account: OpenBackupAccount, password: String)
    func signInIfNeeded()
}

final class BackupPasswordPresenter {
    // MARK: Private properties

    private weak var view: BackupPasswordViewInput?
    private let router: BackupPasswordRouterInput
    private let interactor: BackupPasswordInteractorInput
    private let logger: LoggerProtocol

    private let backupAccounts: [BackupAccount]

    private let passwordInputViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    // MARK: - Constructors

    init(
        backupAccounts: [BackupAccount],
        interactor: BackupPasswordInteractorInput,
        router: BackupPasswordRouterInput,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.backupAccounts = backupAccounts
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard let account = backupAccounts.first(where: { $0.current })?.account else {
            return
        }
        let walletName = account.name ?? account.address
        view?.didReceive(walletName: walletName)
    }

    private func proceed(with backup: OpenBackupAccount) {
        do {
            guard
                let backupAccountTypes = backup.backupAccountType,
                let backupCryptoType = backup.cryptoType?.lowercased(),
                let cryptoType = CryptoType(rawValue: backupCryptoType),
                let name = backup.name
            else {
                throw ConvenienceError(error: "Missing backup types or crypto type")
            }

            var source: MetaAccountImportRequestSource?
            if backupAccountTypes.contains(.passphrase) {
                let mnemonicRequestData = try createMnemonicRequestData(from: backup)
                source = .mnemonic(data: mnemonicRequestData)
            } else if backupAccountTypes.contains(.seed) {
                let keystoreData = try createJsonRequestData(from: backup)
                source = .keystore(data: keystoreData)
            } else if backupAccountTypes.contains(.json) {
                let seedData = try createSeedRequestData(from: backup)
                source = .seed(data: seedData)
            }

            guard let source = source else {
                throw ConvenienceError(error: "Can't create MetaAccountImportRequestSource")
            }

            let request = MetaAccountImportRequest(
                source: source,
                username: name,
                cryptoType: cryptoType
            )
            interactor.importMetaAccount(request: request)
        } catch {
            logger.customError(error)
            showCommonError()
        }
    }

    private func createSeedRequestData(
        from backup: OpenBackupAccount
    ) throws -> MetaAccountImportRequestSource.SeedImportRequestData {
        guard
            let substrateSeed = backup.encryptedSeed?.substrateSeed,
            let substrateDerivationPath = backup.substrateDerivationPath
        else {
            throw ConvenienceError(error: "Can't create SeedImportRequestData")
        }

        let sourceData = MetaAccountImportRequestSource.SeedImportRequestData(
            substrateSeed: substrateSeed,
            ethereumSeed: backup.encryptedSeed?.ethSeed,
            substrateDerivationPath: substrateDerivationPath,
            ethereumDerivationPath: backup.ethDerivationPath
        )
        return sourceData
    }

    private func createJsonRequestData(
        from backup: OpenBackupAccount
    ) throws -> MetaAccountImportRequestSource.KeystoreImportRequestData {
        guard
            let substrateKeystoreData = backup.json?.substrateJson,
            let substrateKeystore = substrateKeystoreData.toUTF8String()
        else {
            throw ConvenienceError(error: "Can't create KeystoreImportRequestData")
        }

        var ethereumKeystore: String?
        if let ethereumKeystoreData = backup.json?.ethJson {
            ethereumKeystore = ethereumKeystoreData.toUTF8String()
        }

        var substratePassword = ""
        var ethereumPassword = ""
        if let password = backup.passphrase {
            substratePassword = password
            ethereumPassword = password
        }
        let sourceData = MetaAccountImportRequestSource.KeystoreImportRequestData(
            substrateKeystore: substrateKeystore,
            ethereumKeystore: ethereumKeystore,
            substratePassword: substratePassword,
            ethereumPassword: ethereumKeystore == nil ? nil : ethereumPassword
        )
        return sourceData
    }

    private func createMnemonicRequestData(
        from backup: OpenBackupAccount
    ) throws -> MetaAccountImportRequestSource.MnemonicImportRequestData {
        guard
            let passphrase = backup.passphrase,
            let mnemonic = interactor.createMnemonicFromString(passphrase),
            let substrateDerivationPath = backup.substrateDerivationPath,
            let ethDerivationPath = backup.ethDerivationPath
        else {
            throw ConvenienceError(error: "Can't create MnemonicImportRequestData")
        }

        let sourceData = MetaAccountImportRequestSource.MnemonicImportRequestData(
            mnemonic: mnemonic,
            substrateDerivationPath: substrateDerivationPath,
            ethereumDerivationPath: ethDerivationPath
        )
        return sourceData
    }

    private func showCommonError() {
        let message = R.string.localizable.commonUndefinedErrorMessage(preferredLanguages: selectedLocale.rLanguages)
        let title = R.string.localizable.commonUndefinedErrorTitle(preferredLanguages: selectedLocale.rLanguages)
        router.present(
            message: message,
            title: title,
            closeAction: nil,
            from: view,
            actions: []
        )
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
            self?.interactor.signInIfNeeded()
        }
        router.present(
            message: nil,
            title: title,
            closeAction: nil,
            from: view,
            actions: [retryAction]
        )
    }
}

// MARK: - BackupPasswordViewOutput

extension BackupPasswordPresenter: BackupPasswordViewOutput {
    func didLoad(view: BackupPasswordViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
        view.setPasswordInputViewModel(passwordInputViewModel)
    }

    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didContinueButtonTapped() {
        let password = passwordInputViewModel.inputHandler.normalizedValue
        view?.didStartLoading()
        guard let account = backupAccounts.first(where: { $0.current })?.account else {
            return
        }
        interactor.importBackup(account: account, password: password)
    }
}

// MARK: - BackupPasswordInteractorOutput

extension BackupPasswordPresenter: BackupPasswordInteractorOutput {
    func showGoogleIssueError() {
        showGoogleIssueAlert()
    }

    func didReceiveAccountImport(error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func didCompleteAccountImport() {
        router.showWalletImportedScreen(backupAccounts: backupAccounts, from: view)
    }

    func didReceiveBackup(result: Result<SSFCloudStorage.OpenBackupAccount, Error>) {
        view?.didStopLoading()
        switch result {
        case let .success(success):
            proceed(with: success)
        case let .failure(failure):
            let error = ConvenienceError(error: failure.localizedDescription)
            router.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - Localizable

extension BackupPasswordPresenter: Localizable {
    func applyLocalization() {}
}

extension BackupPasswordPresenter: BackupPasswordModuleInput {}
