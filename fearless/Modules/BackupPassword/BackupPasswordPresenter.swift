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
}

final class BackupPasswordPresenter {
    // MARK: Private properties

    private weak var view: BackupPasswordViewInput?
    private let router: BackupPasswordRouterInput
    private let interactor: BackupPasswordInteractorInput

    private let backupAccounts: [BackupAccount]

    private let passwordInputViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    // MARK: - Constructors

    init(
        backupAccounts: [BackupAccount],
        interactor: BackupPasswordInteractorInput,
        router: BackupPasswordRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.backupAccounts = backupAccounts
        self.interactor = interactor
        self.router = router
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
        guard
            let passphrase = backup.passphrase,
            let mnemonic = interactor.createMnemonicFromString(passphrase),
            let substrateDerivationPath = backup.substrateDerivationPath,
            let ethDerivationPath = backup.ethDerivationPath,
            let backupCryptoType = backup.cryptoType,
            let rawValue = UInt8(backupCryptoType),
            let cryptoType = CryptoType(rawValue: rawValue),
            let name = backup.name
        else {
            return
        }

        let sourceData = MetaAccountImportRequestSource.MnemonicImportRequestData(
            mnemonic: mnemonic,
            substrateDerivationPath: substrateDerivationPath,
            ethereumDerivationPath: ethDerivationPath
        )
        let source = MetaAccountImportRequestSource.mnemonic(data: sourceData)
        let request = MetaAccountImportRequest(
            source: source,
            username: name,
            cryptoType: cryptoType
        )
        interactor.importMetaAccount(request: request)
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
