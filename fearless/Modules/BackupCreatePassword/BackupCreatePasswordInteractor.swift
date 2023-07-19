import UIKit
import SSFCloudStorage
import RobinHood

protocol BackupCreatePasswordInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didComplete()
}

final class BackupCreatePasswordInteractor: BaseAccountConfirmInteractor {
    var cloudStorage: CloudStorageServiceProtocol?

    // MARK: - Private properties

    private weak var output: BackupCreatePasswordInteractorOutput?

    private let settings: SelectedWalletSettings
    private let eventCenter: EventCenterProtocol
    private var currentOperation: Operation?
    private let createPasswordFlow: BackupCreatePasswordFlow

    private var password: String?

    init(
        createPasswordFlow: BackupCreatePasswordFlow,
        flow: AccountConfirmFlow,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        settings: SelectedWalletSettings,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.createPasswordFlow = createPasswordFlow

        super.init(
            flow: flow,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: operationManager
        )
    }

    override func createAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        guard currentOperation == nil else {
            return
        }

        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            self?.settings.save(value: accountItem)

            return accountItem
        }

        saveOperation.completionBlock = { [weak self] in
            self?.currentOperation = nil
            self?.handleCreateAccountOperation(result: saveOperation.result)
        }

        saveOperation.addDependency(importOperation)

        operationManager.enqueue(
            operations: [importOperation, saveOperation],
            in: .transient
        )
    }

    // MARK: - Private methods

    private func handleCreateAccountOperation(result: Result<MetaAccountModel, Error>?) {
        switch result {
        case let .success(wallet):
            settings.setup()
            eventCenter.notify(with: SelectedAccountChanged())
            saveBackupAccount(wallet: wallet)

        case let .failure(error):
            output?.didReceive(error: error)

        case .none:
            let error = BaseOperationError.parentOperationCancelled
            output?.didReceive(error: error)
        }
    }

    private func saveBackupAccount(wallet: MetaAccountModel) {
        guard let password = password else {
            return
        }
        switch flow {
        case let .wallet(request):

            let account = OpenBackupAccount(
                name: request.username,
                address: wallet.substratePublicKey.toHex(),
                passphrase: request.mnemonic.toString(),
                cryptoType: String(request.cryptoType.rawValue),
                substrateDerivationPath: request.substrateDerivationPath,
                ethDerivationPath: request.ethereumDerivationPath
            )
            cloudStorage?.saveBackupAccount(
                account: account,
                password: password
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.didBackuped(wallet: wallet)
                    self?.output?.didComplete()
                case let .failure(failure):
                    self?.output?.didReceive(error: failure)
                }
            }
        case .chain, .none:
            fatalError()
        }
    }

    private func didBackuped(wallet: MetaAccountModel) {
        let updatedWallet = wallet.replacingIsBackuped(true)
        let saveOperation = accountRepository.saveOperation {
            [updatedWallet]
        } _: {
            []
        }
        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }
}

// MARK: - BackupCreatePasswordInteractorInput

extension BackupCreatePasswordInteractor: BackupCreatePasswordInteractorInput {
    func setup(with output: BackupCreatePasswordInteractorOutput) {
        self.output = output
    }

    func createAndBackupAccount(password: String) {
        self.password = password
        switch createPasswordFlow {
        case .createWallet:
            skipConfirmation()
        case let .backupWallet(wallet, _):
            saveBackupAccount(wallet: wallet)
        }
    }
}
