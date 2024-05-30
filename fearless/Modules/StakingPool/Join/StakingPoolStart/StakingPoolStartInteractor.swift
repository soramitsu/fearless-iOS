import UIKit
import RobinHood
import SSFRuntimeCodingService

final class StakingPoolStartInteractor {
    // MARK: - Private properties

    private weak var output: StakingPoolStartInteractorOutput?
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol
    private let rewardService: RewardCalculatorServiceProtocol
    private let stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol

    init(
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    ) {
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.stakingDurationOperationFactory = stakingDurationOperationFactory
        self.rewardService = rewardService
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
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

    private func fetchNetworkInfo() {
        let fetchMinJoinBondOperation = stakingPoolOperationFactory.fetchMinJoinBondOperation()
        let fetchMinCreateBondOperation = stakingPoolOperationFactory.fetchMinCreateBondOperation()
        let maxStakingPoolsCountOperation = stakingPoolOperationFactory.fetchMaxStakingPoolsCount()
        let maxPoolsMembersOperation = stakingPoolOperationFactory.fetchMaxPoolMembers()
        let existingPoolsCountOperation = stakingPoolOperationFactory.fetchCounterForBondedPools()
        let maxPoolMembersPerPoolOperation = stakingPoolOperationFactory.fetchMaxPoolMembersPerPool()

        let mapOperation = ClosureOperation<StakingPoolNetworkInfo> {
            let minJoinBond = try? fetchMinJoinBondOperation.targetOperation.extractNoCancellableResultData()
            let minCreateBond = try? fetchMinCreateBondOperation.targetOperation.extractNoCancellableResultData()
            let maxPoolsCount = try? maxStakingPoolsCountOperation.targetOperation.extractNoCancellableResultData()
            let maxPoolsMembers = try? maxPoolsMembersOperation.targetOperation.extractNoCancellableResultData()
            let existingPoolsCount = try? existingPoolsCountOperation.targetOperation.extractNoCancellableResultData()
            let maxPoolMembersPerPool = try? maxPoolMembersPerPoolOperation.targetOperation.extractNoCancellableResultData()

            return StakingPoolNetworkInfo(
                minJoinBond: minJoinBond,
                minCreateBond: minCreateBond,
                existingPoolsCount: existingPoolsCount,
                possiblePoolsCount: maxPoolsCount,
                maxMembersInPool: maxPoolMembersPerPool,
                maxPoolsMembers: maxPoolsMembers
            )
        }

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let networkInfo = try mapOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(networkInfo: networkInfo)
                } catch {
                    self?.output?.didReceive(error: error)
                }
            }
        }

        let dependencies = [fetchMinJoinBondOperation.targetOperation,
                            fetchMinCreateBondOperation.targetOperation,
                            maxStakingPoolsCountOperation.targetOperation,
                            maxPoolsMembersOperation.targetOperation,
                            existingPoolsCountOperation.targetOperation,
                            maxPoolMembersPerPoolOperation.targetOperation]

        dependencies.forEach {
            mapOperation.addDependency($0)
        }

        var allOperations: [Operation] = [mapOperation]
        allOperations.append(contentsOf: fetchMinJoinBondOperation.allOperations)
        allOperations.append(contentsOf: fetchMinCreateBondOperation.allOperations)
        allOperations.append(contentsOf: maxStakingPoolsCountOperation.allOperations)
        allOperations.append(contentsOf: maxPoolsMembersOperation.allOperations)
        allOperations.append(contentsOf: existingPoolsCountOperation.allOperations)
        allOperations.append(contentsOf: maxPoolMembersPerPoolOperation.allOperations)

        operationManager.enqueue(
            operations: allOperations,
            in: .transient
        )
    }

    private func fetchStakingDurationInfo() {
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
    }
}

// MARK: - StakingPoolStartInteractorInput

extension StakingPoolStartInteractor: StakingPoolStartInteractorInput {
    func setup(with output: StakingPoolStartInteractorOutput) {
        self.output = output

        rewardService.setup()
        provideRewardCalculator()
        fetchStakingDurationInfo()
        fetchNetworkInfo()
    }
}

extension StakingPoolStartInteractor: RuntimeConstantFetching {}
