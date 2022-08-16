import UIKit
import RobinHood

final class StakingPoolStartInteractor {
    // MARK: - Private properties

    private weak var output: StakingPoolStartInteractorOutput?
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol
    private let rewardService: RewardCalculatorServiceProtocol

    init(
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol,
        rewardService: RewardCalculatorServiceProtocol
    ) {
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.stakingDurationOperationFactory = stakingDurationOperationFactory
        self.rewardService = rewardService
    }

    private func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.output?.didReceive(calculator: engine)
                } catch {
                    self?.output?.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }
}

// MARK: - StakingPoolStartInteractorInput

extension StakingPoolStartInteractor: StakingPoolStartInteractorInput {
    func setup(with output: StakingPoolStartInteractorOutput) {
        self.output = output

        let durationOperation = stakingDurationOperationFactory.createDurationOperation(from: runtimeService)

        durationOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let stakingDuration = try durationOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(stakingDuration: stakingDuration)
                } catch {
                    self?.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: durationOperation.allOperations, in: .transient)

        rewardService.setup()

        provideRewardCalculator()
    }
}

extension StakingPoolStartInteractor: RuntimeConstantFetching {}
