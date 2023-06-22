import Foundation
import SoraFoundation
import SSFCloudStorage

protocol BackupPasswordViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol, CloudStorageUIDelegate {
    func didReceive(walletName: String)
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

    private var password: String?

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
            let mnemonic = interactor.createMnemonicFromString(passphrase) else {
            return
        }
        // TODO: - paste ethereumDerivationPath from account
        let sourceData = MetaAccountImportRequestSource.MnemonicImportRequestData(
            mnemonic: mnemonic,
            substrateDerivationPath: backup.derivationPath ?? "",
            ethereumDerivationPath: "//44//60//0/0/0"
        )
        let source = MetaAccountImportRequestSource.mnemonic(data: sourceData)
        let cryptoType = CryptoType(rawValue: backup.cryptoType ?? 0) ?? .sr25519
        let request = MetaAccountImportRequest(
            source: source,
            username: backup.name ?? backup.address,
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
    }

    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didContinueButtonTapped() {
        guard let password = password else {
            return
        }
        view?.didStartLoading()
        guard let account = backupAccounts.first(where: { $0.current })?.account else {
            return
        }
        interactor.importBackup(account: account, password: password)
    }

    func passwordDidChainged(password: String) {
        self.password = password
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
            router.present(error: failure, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - Localizable

extension BackupPasswordPresenter: Localizable {
    func applyLocalization() {}
}

extension BackupPasswordPresenter: BackupPasswordModuleInput {}
