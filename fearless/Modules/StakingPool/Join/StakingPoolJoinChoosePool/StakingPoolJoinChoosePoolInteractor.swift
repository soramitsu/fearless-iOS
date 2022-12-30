import UIKit
import RobinHood

final class StakingPoolJoinChoosePoolInteractor {
    // MARK: - Private properties

    private weak var output: StakingPoolJoinChoosePoolInteractorOutput?
    private let stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol

    init(
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
        self.operationManager = operationManager
    }

    private func fetchAvailablePools() {
        let fetchOperation = stakingPoolOperationFactory.fetchBondedPoolsOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let pools = try fetchOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceivePools(pools)
                } catch {
                    self?.output?.didReceiveError(error)
                }
            }
        }

        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

// MARK: - StakingPoolJoinChoosePoolInteractorInput

extension StakingPoolJoinChoosePoolInteractor: StakingPoolJoinChoosePoolInteractorInput {
    func setup(with output: StakingPoolJoinChoosePoolInteractorOutput) {
        self.output = output

        fetchAvailablePools()
    }
}
