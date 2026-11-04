import Foundation
import SoraFoundation
import SSFCloudStorage
import SSFModels

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
                let backupAccountTypes = backup.backupAccountType ?? inferredAccountTypes(of: backup),
                let backupCryptoType = backup.cryptoType?.lowercased(),
                let name = backup.name
            else {
                throw ConvenienceError(error: "Missing backup types or crypto type")
            }

            var source: MetaAccountImportRequestSource?
            if backupAccountTypes.contains(.passphrase) {
                let mnemonicRequestData = try createMnemonicRequestData(from: backup)
                source = .mnemonic(data: mnemonicRequestData)
            } else if backupAccountTypes.contains(.seed) {
                let keystoreData = try createSeedRequestData(from: backup)
                source = .seed(data: keystoreData)
            } else if backupAccountTypes.contains(.json) {
                let seedData = try createJsonRequestData(from: backup)
                source = .keystore(data: seedData)
            }

            guard var source = source else {
                throw ConvenienceError(error: "Can't create MetaAccountImportRequestSource")
            }

            let cryptoType: CryptoType
            if let fromStringValueCryptoType = CryptoType(rawValue: backupCryptoType) {
                cryptoType = fromStringValueCryptoType
            } else if let uint8 = UInt8(backupCryptoType), let fromUInt8ValueCryptoType = CryptoType(rawValue: uint8) {
                cryptoType = fromUInt8ValueCryptoType
            } else {
                throw ConvenienceError(error: "Wrong crypto type in google backup")
            }

            if case var .mnemonic(data) = source {
                data.substratePasswordRule = restoringSubstratePasswordRule(
                    data, address: backup.address, cryptoType: cryptoType
                )
                source = .mnemonic(data: data)
            }

            let request = MetaAccountImportRequest(
                source: source,
                username: name,
                cryptoType: cryptoType,
                defaultChainId: nil
            )
            interactor.importMetaAccount(request: request)
        } catch {
            logger.customError(error)
            showCommonError()
        }
    }

    /// A wallet imported with an earlier browser extension's account restores that account: the rule
    /// (SubstratePasswordRule) whose account the backup is filed under, otherwise the current one.
    private func restoringSubstratePasswordRule(
        _ data: MetaAccountImportRequestSource.MnemonicImportRequestData,
        address: String?,
        cryptoType: CryptoType
    ) -> SubstratePasswordRule {
        guard let address,
              SubstratePasswordRule.distinctRules(forSubstrateDerivationPath: data.substrateDerivationPath).count > 1
        else {
            return .nfkd
        }
        let accounts = try? SubstratePasswordRule.accounts(
            mnemonic: data.mnemonic,
            derivationPath: data.substrateDerivationPath,
            cryptoType: cryptoType
        )
        return accounts?.first { $0.address == address }?.rule ?? .nfkd
    }

    private func createSeedRequestData(
        from backup: OpenBackupAccount
    ) throws -> MetaAccountImportRequestSource.SeedImportRequestData {
        guard let substrateSeed = backup.encryptedSeed?.substrateSeed else {
            throw ConvenienceError(error: "Can't create SeedImportRequestData")
        }

        // The Ethereum seed is the private key itself; the import uses it as it is whatever the
        // path says, but only when a path is present. iOS before 4.2 wrote seed backups without one.
        let ethereumSeed = backup.encryptedSeed?.ethSeed
        let sourceData = MetaAccountImportRequestSource.SeedImportRequestData(
            substrateSeed: substrateSeed,
            ethereumSeed: ethereumSeed,
            substrateDerivationPath: backup.substrateDerivationPath ?? "",
            ethereumDerivationPath: ethereumSeed == nil ? backup.ethDerivationPath : backup.ethDerivationPath ?? ""
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

        let password = passwordInputViewModel.inputHandler.normalizedValue

        let sourceData = MetaAccountImportRequestSource.KeystoreImportRequestData(
            substrateKeystore: substrateKeystore,
            ethereumKeystore: ethereumKeystore,
            substratePassword: password,
            ethereumPassword: ethereumKeystore == nil ? nil : password
        )
        return sourceData
    }

    private func createMnemonicRequestData(
        from backup: OpenBackupAccount
    ) throws -> MetaAccountImportRequestSource.MnemonicImportRequestData {
        guard
            let passphrase = backup.passphrase,
            let mnemonic = interactor.createMnemonicFromString(passphrase)
        else {
            throw ConvenienceError(error: "Can't create MnemonicImportRequestData")
        }

        // A backup without a path means the empty path, as Android restores it.
        let sourceData = MetaAccountImportRequestSource.MnemonicImportRequestData(
            mnemonic: mnemonic,
            substrateDerivationPath: backup.substrateDerivationPath ?? "",
            ethereumDerivationPath: backup.ethDerivationPath ?? ""
        )
        return sourceData
    }

    /// Backups written before the type list existed (Android 1.x) hold only a phrase; any
    /// other backup without a list is read by the material it carries.
    private func inferredAccountTypes(of backup: OpenBackupAccount) -> [OpenBackupAccount.BackupAccountType]? {
        if backup.passphrase?.isEmpty == false {
            return [.passphrase]
        }
        if backup.encryptedSeed?.substrateSeed?.isEmpty == false {
            return [.seed]
        }
        if backup.json?.substrateJson?.isEmpty == false {
            return [.json]
        }
        return nil
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
