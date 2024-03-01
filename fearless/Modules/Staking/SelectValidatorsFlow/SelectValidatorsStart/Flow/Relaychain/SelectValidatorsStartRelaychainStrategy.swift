import Foundation
import RobinHood

protocol SelectValidatorsStartRelaychainStrategyOutput: AnyObject {
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>)
    func didReceiveMaxNominations(result: Result<Int, Error>)
}

final class SelectValidatorsStartRelaychainStrategy: RuntimeConstantFetching {
    private let operationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let staked: Decimal
    private weak var output: SelectValidatorsStartRelaychainStrategyOutput?

    init(
        operationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        staked: Decimal,
        output: SelectValidatorsStartRelaychainStrategyOutput?
    ) {
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.staked = staked
        self.output = output
    }

    private func prepareRecommendedValidatorList() {
        let wrapper = operationFactory.fetchAllValidators(staked: staked)

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

extension SelectValidatorsStartRelaychainStrategy: SelectValidatorsStartStrategy {
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
