import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore

final class AccountImportInteractor {
    weak var presenter: AccountImportInteractorOutputProtocol!

    private(set) lazy var jsonDecoder = JSONDecoder()
    private(set) lazy var mnemonicCreator = IRMnemonicCreator()

    let accountOperationFactory: AccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol
    let keystoreImportService: KeystoreImportServiceProtocol

    private(set) var settings: SettingsManagerProtocol

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         settings: SettingsManagerProtocol,
         keystoreImportService: KeystoreImportServiceProtocol) {
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.settings = settings
        self.keystoreImportService = keystoreImportService
    }

    private func setupKeystoreImportObserver() {
        keystoreImportService.add(observer: self)
        handleIfNeededKeystoreImport()
    }

    private func handleIfNeededKeystoreImport() {
        if let definition = keystoreImportService.definition {
            keystoreImportService.clear()

            do {
                let jsonData = try JSONEncoder().encode(definition)

                if let text = String(data: jsonData, encoding: .utf8) {
                    presenter.didSuggestKeystore(text: text, username: definition.meta.name)
                }

            } catch {
                presenter.didReceiveAccountImport(error: error)
            }
        }
    }

    private func provideMetadata() {
        let availableAddressTypes: [SNAddressType] = [.kusamaMain, .polkadotMain, .genericSubstrate]

        let defaultConnection = ConnectionItem.defaultConnection

        let networkType = SNAddressType(rawValue: defaultConnection.type) ?? .kusamaMain

        let metadata = AccountImportMetadata(availableSources: AccountImportSource.allCases,
                                             defaultSource: .mnemonic,
                                             availableAddressTypes: availableAddressTypes,
                                             defaultAddressType: networkType,
                                             availableCryptoTypes: CryptoType.allCases,
                                             defaultCryptoType: .sr25519)

        presenter.didReceiveAccountImport(metadata: metadata)
    }

    private func updateSelectedAccountFromResult(_ result: Result<AccountItem, Error>?,
                                                 connection: ConnectionItem) {
        if case .success(let accountItem) = result {
            settings.selectedAccount = accountItem
            settings.selectedConnection = connection
        }
    }

    private func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
        let persistentOperation = accountRepository.saveOperation({
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return [accountItem]
        }, { [] })

        persistentOperation.addDependency(importOperation)

        let connectionOperation: BaseOperation<(AccountItem, ConnectionItem)> = ClosureOperation {
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let type = try SS58AddressFactory().type(fromAddress: accountItem.address)

            guard let connectionItem = ConnectionItem.supportedConnections
                .first(where: { $0.type == type.int8Value }) else {
                throw AccountImportError.unsupportedNetwork
            }

            return (accountItem, connectionItem)
        }

        connectionOperation.addDependency(persistentOperation)

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch connectionOperation.result {
                case .success(let (accountItem, connectionItem)):
                    self?.settings.selectedAccount = accountItem
                    self?.settings.selectedConnection = connectionItem

                    self?.presenter?.didCompleAccountImport()
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [importOperation, persistentOperation, connectionOperation],
                                 in: .sync)
    }
}

extension AccountImportInteractor: AccountImportInteractorInputProtocol {
    func setup() {
        provideMetadata()
        setupKeystoreImportObserver()
    }

    func importAccountWithMnemonic(request: AccountImportMnemonicRequest) {
        guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: request.mnemonic) else {
            presenter.didReceiveAccountImport(error: AccountImportError.invalidMnemonicFormat)
            return
        }

        let creationRequest = AccountCreationRequest(username: request.username,
                                                     type: request.type,
                                                     derivationPath: request.derivationPath,
                                                     cryptoType: request.cryptoType)

        let accountOperation = accountOperationFactory.newAccountOperation(request: creationRequest,
                                                                           mnemonic: mnemonic)

        importAccountUsingOperation(accountOperation)
    }

    func importAccountWithSeed(request: AccountImportSeedRequest) {
        let operation = accountOperationFactory.newAccountOperation(request: request)
        importAccountUsingOperation(operation)
    }

    func importAccountWithKeystore(request: AccountImportKeystoreRequest) {
        let operation = accountOperationFactory.newAccountOperation(request: request)
        importAccountUsingOperation(operation)
    }

    func deriveUsernameFromKeystore(_ keystore: String) {
        if
            let data = keystore.data(using: .utf8),
            let definition = try? jsonDecoder.decode(KeystoreDefinition.self, from: data) {
            presenter.didDeriveKeystore(username: definition.meta.name)
        }
    }
}

extension AccountImportInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        handleIfNeededKeystoreImport()
    }
}
