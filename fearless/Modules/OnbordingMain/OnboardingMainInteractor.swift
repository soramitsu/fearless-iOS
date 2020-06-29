import Foundation
import RobinHood
import SoraKeystore

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainOutputInteractorProtocol?

    let accountOperationFactory: AccountOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    private var currentOperation: Operation?

    init(accountOperationFactory: AccountOperationFactoryProtocol, operationManager: OperationManagerProtocol) {
        self.accountOperationFactory = accountOperationFactory
        self.operationManager = operationManager
    }

}

extension OnboardingMainInteractor: OnboardingMainInputInteractorProtocol {
    func signup() {
        guard currentOperation == nil else {
            return
        }

        presenter?.didStartSignup()

        let operation = accountOperationFactory.newAccountOperation()

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
