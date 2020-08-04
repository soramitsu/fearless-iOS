import Foundation
import SoraKeystore
import IrohaCrypto
import RobinHood
import SoraFoundation

final class AccessRestoreInteractor {
    weak var presenter: AccessRestoreInteractorOutputProtocol?

    let accountOperationFactory: AccountOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let settings: SettingsManagerProtocol
    let mnemonicCreator: IRMnemonicCreatorProtocol

    private var currentOperation: Operation?

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         mnemonicCreator: IRMnemonicCreatorProtocol,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol) {
        self.accountOperationFactory = accountOperationFactory
        self.mnemonicCreator = mnemonicCreator
        self.settings = settings
        self.operationManager = operationManager
    }
}

extension AccessRestoreInteractor: AccessRestoreInteractorInputProtocol {
    func restoreAccess(mnemonic: String) {
        guard currentOperation == nil else {
            return
        }

        let selectedConnection = settings.selectedConnection

        guard let addressType = SNAddressType(rawValue: selectedConnection.type) else {
            presenter?.didReceiveRestoreAccess(error: AccessRestoreInteractorError.undefinedConnectionType)
            return
        }

        guard let mnemonicWrapper = try? mnemonicCreator.mnemonic(fromList: mnemonic) else {
            return
        }

        // TODO: Will be implemented in FLW-82

        let accountRequest = AccountCreationRequest(username: "",
                                                    type: addressType,
                                                    derivationPath: "",
                                                    cryptoType: .sr25519)

        let operation = accountOperationFactory.newAccountOperation(request: accountRequest,
                                                                    mnemonic: mnemonicWrapper)
        currentOperation = operation

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.currentOperation = nil

                switch operation.result {
                case .success:
                    self?.presenter?.didRestoreAccess(from: mnemonic)
                case .failure(let error):
                    self?.presenter?.didReceiveRestoreAccess(error: error)
                case .none:
                    self?.presenter?.didReceiveRestoreAccess(error: BaseOperationError.parentOperationCancelled)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}
