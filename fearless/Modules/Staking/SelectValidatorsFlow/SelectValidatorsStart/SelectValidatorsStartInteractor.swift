import UIKit
import RobinHood
import FearlessUtils
import IrohaCrypto

final class SelectValidatorsStartInteractor {
    weak var presenter: SelectValidatorsStartInteractorOutputProtocol!

    let operationFactory: ValidatorOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(
        operationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.operationFactory = operationFactory
        self.operationManager = operationManager
    }

    private func prepareRecommendedValidatorList() {
        let wrapper = operationFactory.allElectedOperation()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let validators = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(validators: validators)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}

extension SelectValidatorsStartInteractor: SelectValidatorsStartInteractorInputProtocol {
    func setup() {
        prepareRecommendedValidatorList()
    }
}
