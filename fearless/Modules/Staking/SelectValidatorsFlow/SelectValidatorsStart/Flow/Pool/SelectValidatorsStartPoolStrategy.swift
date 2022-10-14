import Foundation
import RobinHood

protocol SelectValidatorsStartPoolStrategyOutput: AnyObject {
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>)
    func didReceiveMaxNominations(result: Result<Int, Error>)
}

final class SelectValidatorsStartPoolStrategy: RuntimeConstantFetching {
    private let operationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private weak var output: SelectValidatorsStartPoolStrategyOutput?

    init(
        operationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        output: SelectValidatorsStartPoolStrategyOutput?
    ) {
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.output = output
    }

    private func prepareRecommendedValidatorList() {
        let wrapper = operationFactory.allElectedOperation()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let validators = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceiveValidators(result: .success(validators))
                } catch {
                    self?.output?.didReceiveValidators(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}

extension SelectValidatorsStartPoolStrategy: SelectValidatorsStartStrategy {
    func setup() {
        prepareRecommendedValidatorList()

        fetchConstant(
            for: .maxNominations,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Int, Error>) in
            self?.output?.didReceiveMaxNominations(result: result)
        }
    }
}
