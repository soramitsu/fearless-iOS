import Foundation
import RobinHood

protocol SelectValidatorsStartParachainStrategyOutput: AnyObject {
    func didReceiveMaxDelegations(result: Result<Int, Error>)
    func didReceiveSelectedCandidates(selectedCandidates: [ParachainStakingCandidate])
}

final class SelectValidatorsStartParachainStrategy: RuntimeConstantFetching {
    let operationFactory: ParachainValidatorOperationFactory
    let operationManager: OperationManagerProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    private weak var output: SelectValidatorsStartParachainStrategyOutput?

    init(
        operationFactory: ParachainValidatorOperationFactory,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        output: SelectValidatorsStartParachainStrategyOutput?
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
                    let response = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceiveSelectedCandidates(selectedCandidates: response ?? [])
                } catch {
                    print("error: ", error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}

extension SelectValidatorsStartParachainStrategy: SelectValidatorsStartStrategy {
    func setup() {
        prepareRecommendedValidatorList()

        fetchConstant(
            for: .maxDelegationsPerDelegator,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Int, Error>) in
            self?.output?.didReceiveMaxDelegations(result: result)
        }
    }
}
