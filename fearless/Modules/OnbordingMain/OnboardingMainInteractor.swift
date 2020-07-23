import Foundation
import RobinHood
import SoraKeystore
import IrohaCrypto

enum OnboardingMainInteractorError: Error {
    case undefinedConnectionType
}

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainOutputInteractorProtocol?

    let accountOperationFactory: AccountOperationFactoryProtocol
    let settings: SettingsManagerProtocol
    let operationManager: OperationManagerProtocol

    private var currentOperation: Operation?

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol) {
        self.accountOperationFactory = accountOperationFactory
        self.settings = settings
        self.operationManager = operationManager
    }

}

extension OnboardingMainInteractor: OnboardingMainInputInteractorProtocol {
    func signup() {
        guard currentOperation == nil else {
            return
        }

        presenter?.didStartSignup()

        guard let addressType = SNAddressType(rawValue: settings.selectedConnection.type) else {
            presenter?.didReceiveSignup(error: OnboardingMainInteractorError.undefinedConnectionType)
            return
        }

        let operation = accountOperationFactory.newAccountOperation(addressType: addressType)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.currentOperation = nil

                switch operation.result {
                case .success:
                    self?.presenter?.didCompleteSignup()
                case .failure(let error):
                    self?.presenter?.didReceiveSignup(error: error)
                case .none:
                    self?.presenter?.didReceiveSignup(error: BaseOperationError.parentOperationCancelled)
                }
            }
        }

        currentOperation = operation

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}
