import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore

class BaseAccountImportInteractor {
    weak var presenter: AccountImportInteractorOutputProtocol!

    private(set) lazy var jsonDecoder = JSONDecoder()
    private(set) lazy var mnemonicCreator = IRMnemonicCreator()

    let accountOperationFactory: AccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let supportedAddressTypes: [SNAddressType]
    let defaultAddressType: SNAddressType

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         supportedAddressTypes: [SNAddressType],
         defaultAddressType: SNAddressType) {
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.keystoreImportService = keystoreImportService
        self.supportedAddressTypes = supportedAddressTypes
        self.defaultAddressType = defaultAddressType
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
                    presenter.didSuggestKeystore(text: text, username: definition.meta?.name)
                }

            } catch {
                presenter.didReceiveAccountImport(error: error)
            }
        }
    }

    private func provideMetadata() {
        let metadata = AccountImportMetadata(availableSources: AccountImportSource.allCases,
                                             defaultSource: .mnemonic,
                                             availableAddressTypes: supportedAddressTypes,
                                             defaultAddressType: defaultAddressType,
                                             availableCryptoTypes: CryptoType.allCases,
                                             defaultCryptoType: .sr25519)

        presenter.didReceiveAccountImport(metadata: metadata)
    }

    func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {}
}

extension BaseAccountImportInteractor: AccountImportInteractorInputProtocol {
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
            let username = try? jsonDecoder.decode(KeystoreDefinition.self, from: data).meta?.name {
            presenter.didDeriveKeystore(username: username)
        }
    }
}

extension BaseAccountImportInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        handleIfNeededKeystoreImport()
    }
}
