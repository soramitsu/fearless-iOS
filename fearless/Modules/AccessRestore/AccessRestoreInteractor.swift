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

    private var currentOperation: Operation?

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol) {
        self.accountOperationFactory = accountOperationFactory
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

        let operation = accountOperationFactory.deriveAccountOperation(addressType: addressType,
                                                                       mnemonic: mnemonic)
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
