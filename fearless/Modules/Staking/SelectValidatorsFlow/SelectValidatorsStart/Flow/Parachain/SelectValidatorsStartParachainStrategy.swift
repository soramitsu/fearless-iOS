import Foundation
import RobinHood

protocol SelectValidatorsStartParachainStrategyOutput: AnyObject {
    func didReceiveMaxDelegations(result: Result<Int, Error>)
    func didReceiveMaxTopDelegationsPerCandidate(result: Result<Int, Error>)
    func didReceiveMaxBottomDelegationsPerCandidate(result: Result<Int, Error>)
    func didReceiveSelectedCandidates(selectedCandidates: [ParachainStakingCandidateInfo])
    func didReceiveTopDelegations(delegations: [AccountAddress: ParachainStakingDelegations])
    func didReceiveBottomDelegations(delegations: [AccountAddress: ParachainStakingDelegations])
}

final class SelectValidatorsStartParachainStrategy: RuntimeConstantFetching {
    let operationFactory: ParachainCollatorOperationFactory
    let operationManager: OperationManagerProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    private weak var output: SelectValidatorsStartParachainStrategyOutput?

    init(
        operationFactory: ParachainCollatorOperationFactory,
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

                    if let collators = response {
                        self?.requestTopDelegationsForEachCollator(collators: collators)
                    }
                } catch {
                    print("error: ", error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    private func requestTopDelegationsForEachCollator(collators: [ParachainStakingCandidateInfo]) {
        let topDelegationsOperation = operationFactory.collatorTopDelegations {
            collators.map(\.owner)
        }

        topDelegationsOperation.targetOperation.completionBlock = { [weak self] in
            do {
                let response = try topDelegationsOperation.targetOperation.extractNoCancellableResultData()

                guard let delegations = response else {
                    return
                }

                self?.output?.didReceiveTopDelegations(delegations: delegations)
            } catch {
                print("error: ", error)
            }
        }

        operationManager.enqueue(operations: topDelegationsOperation.allOperations, in: .transient)
    }

    private func requestBottomDelegationsForEachCollator(collators: [ParachainStakingCandidateInfo]) {
        let bottomDelegationsOperation = operationFactory.collatorBottomDelegations {
            collators.map(\.owner)
        }

        bottomDelegationsOperation.targetOperation.completionBlock = { [weak self] in
            do {
                let response = try bottomDelegationsOperation.targetOperation.extractNoCancellableResultData()

                guard let delegations = response else {
                    return
                }

                self?.output?.didReceiveBottomDelegations(delegations: delegations)
            } catch {
                print("error: ", error)
            }
        }

        operationManager.enqueue(operations: bottomDelegationsOperation.allOperations, in: .transient)
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

        fetchConstant(
            for: .maxTopDelegationsPerCandidate,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Int, Error>) in
            self?.output?.didReceiveMaxTopDelegationsPerCandidate(result: result)
        }

        fetchConstant(
            for: .maxBottomDelegationsPerCandidate,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Int, Error>) in
            self?.output?.didReceiveMaxBottomDelegationsPerCandidate(result: result)
        }
    }
}
