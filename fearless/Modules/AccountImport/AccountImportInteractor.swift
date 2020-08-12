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
    let operationManager: OperationManagerProtocol

    private(set) var settings: SettingsManagerProtocol

    private var currentOperation: Operation?

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         operationManager: OperationManagerProtocol,
         settings: SettingsManagerProtocol) {
        self.accountOperationFactory = accountOperationFactory
        self.operationManager = operationManager
        self.settings = settings
    }
}

extension AccountImportInteractor: AccountImportInteractorInputProtocol {
    func setup() {
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

    func importAccountWithMnemonic(request: AccountImportMnemonicRequest) {
        guard currentOperation == nil else {
            return
        }

        guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: request.mnemonic) else {
            presenter.didReceiveAccountImport(error: AccountImportError.invalidMnemonicFormat)
            return
        }

        let creationRequest = AccountCreationRequest(username: request.username,
                                                     type: request.type,
                                                     derivationPath: request.derivationPath,
                                                     cryptoType: request.cryptoType)

        let operation = accountOperationFactory.newAccountOperation(request: creationRequest,
                                                                    mnemonic: mnemonic,
                                                                    connection: nil)

        currentOperation = operation

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.currentOperation = nil

                switch operation.result {
                case .success:
                    self?.settings.accountConfirmed = true
                    self?.presenter?.didCompleAccountImport()
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func importAccountWithSeed(request: AccountImportSeedRequest) {
        guard currentOperation == nil else {
            return
        }

        let operation = accountOperationFactory.newAccountOperation(request: request,
                                                                    connection: nil)

        currentOperation = operation

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.currentOperation = nil

                switch operation.result {
                case .success:
                    self?.presenter?.didCompleAccountImport()
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func importAccountWithKeystore(request: AccountImportKeystoreRequest) {
        guard currentOperation == nil else {
            return
        }

        let operation = accountOperationFactory.newAccountOperation(request: request,
                                                                    connection: nil)

        currentOperation = operation

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.currentOperation = nil

                switch operation.result {
                case .success:
                    self?.presenter?.didCompleAccountImport()
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func deriveUsernameFromKeystore(_ keystore: String) {
        if
            let data = keystore.data(using: .utf8),
            let definition = try? jsonDecoder.decode(KeystoreDefinition.self, from: data) {
            presenter.didDeriveKeystore(username: definition.meta.name)
        }
    }
}
