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
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        settings: SelectedWalletSettings,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.createPasswordFlow = createPasswordFlow

        var flow: AccountConfirmFlow?
        if let mnemonicRequest = createPasswordFlow.mnemonicRequest {
            flow = .wallet(mnemonicRequest)
        }

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

    // create new wallet with google backup flow
    private func handleCreateAccountOperation(result: Result<MetaAccountModel, Error>?) {
        switch result {
        case let .success(wallet):
            settings.setup()
            eventCenter.notify(with: SelectedAccountChanged())
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
                saveBackupAccount(wallet: wallet, requestType: .mnemonic(request))
            default:
                break
            }

        case let .failure(error):
            output?.didReceive(error: error)

        case .none:
            let error = BaseOperationError.parentOperationCancelled
            output?.didReceive(error: error)
        }
    }

    private func saveBackupAccount(wallet: MetaAccountModel, requestType: BackupCreatePasswordFlow.RequestType) {
        guard let password = password else {
            return
        }

        switch requestType {
        case let .mnemonic(metaAccountImportMnemonicRequest):
            backupMnemonic(wallet: wallet, request: metaAccountImportMnemonicRequest, password: password)
        case let .jsons(jsons):
            backupJsons(wallet: wallet, jsons: jsons, password: password)
        case let .seeds(seeds):
            backupSeeds(wallet: wallet, seeds: seeds, password: password)
        }
    }

    private func backupSeeds(
        wallet: MetaAccountModel,
        seeds: [ExportSeedData],
        password: String
    ) {
        let substrateRestoreSeed = seeds.first(where: { $0.chain.chainBaseType == .substrate })
        let ethereumRestoreSeed = seeds.first(where: { $0.chain.chainBaseType == .ethereum })

        let seed = OpenBackupAccount.Seed(
            substrateSeed: substrateRestoreSeed?.seed.toUTF8String(),
            ethSeed: ethereumRestoreSeed?.seed.toUTF8String()
        )
        let account = OpenBackupAccount(
            name: wallet.name,
            address: wallet.substratePublicKey.toHex(),
            substrateDerivationPath: substrateRestoreSeed?.derivationPath,
            ethDerivationPath: ethereumRestoreSeed?.derivationPath,
            backupAccountTypes: [.seed],
            seed: seed
        )
        saveBackupAccountToCloudStorage(account: account, password: password, wallet: wallet)
    }

    private func backupJsons(
        wallet: MetaAccountModel,
        jsons: [RestoreJson],
        password: String
    ) {
        let substrateRestoreJson = jsons.first(where: { $0.chain.chainBaseType == .substrate })
        let ethereumRestoreJson = jsons.first(where: { $0.chain.chainBaseType == .ethereum })

        let json = OpenBackupAccount.Json(
            substrateJson: substrateRestoreJson?.data.asSecretData(),
            ethJson: ethereumRestoreJson?.data.asSecretData()
        )
        let account = OpenBackupAccount(
            name: wallet.name,
            address: wallet.substratePublicKey.toHex(),
            backupAccountTypes: [.json],
            json: json
        )
        saveBackupAccountToCloudStorage(account: account, password: password, wallet: wallet)
    }

    private func backupMnemonic(
        wallet: MetaAccountModel,
        request: MetaAccountImportMnemonicRequest,
        password: String
    ) {
        let account = OpenBackupAccount(
            name: request.username,
            address: wallet.substratePublicKey.toHex(),
            passphrase: request.mnemonic.toString(),
            cryptoType: String(request.cryptoType.rawValue),
            substrateDerivationPath: request.substrateDerivationPath,
            ethDerivationPath: request.ethereumDerivationPath
        )
        saveBackupAccountToCloudStorage(account: account, password: password, wallet: wallet)
    }

    private func saveBackupAccountToCloudStorage(
        account: OpenBackupAccount,
        password: String,
        wallet: MetaAccountModel
    ) {
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
        case let .backupWallet(wallet, requestType):
            saveBackupAccount(wallet: wallet, requestType: requestType)
        }
    }
}
