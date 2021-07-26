import UIKit
import RobinHood
import FearlessUtils
import IrohaCrypto

final class SelectValidatorsStartInteractor: RuntimeConstantFetching {
    weak var presenter: SelectValidatorsStartInteractorOutputProtocol!

    let operationFactory: ValidatorOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let runtimeService: RuntimeCodingServiceProtocol

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        operationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.runtimeService = runtimeService
        self.operationFactory = operationFactory
        self.operationManager = operationManager
    }

    private func prepareRecommendedValidatorList() {
        let wrapper = operationFactory.allElectedOperation()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let validators = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceiveValidators(result: .success(validators))
                } catch {
                    self?.presenter.didReceiveValidators(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}

extension SelectValidatorsStartInteractor: SelectValidatorsStartInteractorInputProtocol {
    func setup() {
        prepareRecommendedValidatorList()

        fetchConstant(
            for: .maxNominations,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Int, Error>) in
            self?.presenter.didReceiveMaxNominations(result: result)
        }
    }
}
