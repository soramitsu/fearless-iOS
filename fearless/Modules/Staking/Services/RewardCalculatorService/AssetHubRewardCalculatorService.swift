import Foundation
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
import BigInt

final class AssetHubRewardCalculatorService: RewardCalculatorServiceProtocol {
    private let chainId: String
    private let registry: ChainRegistryProtocol
    private let validators: EraValidatorServiceProtocol
    private let storage: StorageRequestFactoryProtocol
    private let manager: OperationManagerProtocol
    private let duration: StakingDurationOperationFactoryProtocol
    private let lock = NSLock()
    private var generation = UUID()
    private var active = false

    init(
        chainId: String,
        registry: ChainRegistryProtocol,
        validators: EraValidatorServiceProtocol,
        storage: StorageRequestFactoryProtocol,
        manager: OperationManagerProtocol,
        duration: StakingDurationOperationFactoryProtocol = StakingDurationOperationFactory()
    ) {
        self.chainId = chainId
        self.registry = registry
        self.validators = validators
        self.storage = storage
        self.manager = manager
        self.duration = duration
    }

    func setup() {
        lock.lock()
        active = true
        lock.unlock()
        validators.setup()
    }

    func throttle() {
        lock.lock()
        active = false
        generation = UUID()
        lock.unlock()
    }

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        lock.lock()
        let request = generation
        let isActive = active
        lock.unlock()
        guard isActive else { return BaseOperation.createWithError(BaseOperationError.parentOperationCancelled) }
        guard AssetHubStakingRoute.staking(on: chainId) != nil,
              let runtime = registry.getRuntimeProvider(for: chainId),
              let connection = registry.getConnection(for: chainId) else {
            return BaseOperation.createWithError(StakingServiceFactoryError.stakingUnavailable)
        }
        let coder = runtime.fetchCoderFactoryOperation()
        let era = validators.fetchInfoOperation()
        let timing = duration.createDurationOperation(from: runtime)
        let keys: () throws -> [StringScaleMapper<EraIndex>] = {
            let activeEra = try era.extractNoCancellableResultData().activeEra
            guard activeEra > 0 else { throw EraValidatorServiceError.unexpectedInfo }
            return [StringScaleMapper(value: activeEra - 1)]
        }
        let rewards: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> = storage.queryItems(
            engine: connection, keyParams: keys,
            factory: { try coder.extractNoCancellableResultData() }, storagePath: .totalValidatorReward
        )
        let points: CompoundOperationWrapper<[StorageResponse<EraRewardPoints>]> = storage.queryItems(
            engine: connection, keyParams: keys,
            factory: { try coder.extractNoCancellableResultData() }, storagePath: .rewardPointsPerValidator
        )
        (rewards.allOperations + points.allOperations).forEach {
            $0.addDependency(coder)
            $0.addDependency(era)
        }
        let result = ClosureOperation<RewardCalculatorEngineProtocol> { [weak self] in
            guard let self = self else { throw BaseOperationError.parentOperationCancelled }
            self.lock.lock()
            let current = self.active && self.generation == request
            self.lock.unlock()
            guard current else { throw BaseOperationError.parentOperationCancelled }
            guard let reward = try rewards.targetOperation.extractNoCancellableResultData().first?.value?.value,
                  let distribution = try points.targetOperation.extractNoCancellableResultData().first?.value else {
                throw EraValidatorServiceError.unexpectedInfo
            }
            return try AssetHubRewardCalculatorEngine(
                reward: reward, points: distribution,
                validators: era.extractNoCancellableResultData().validators,
                eraDuration: timing.targetOperation.extractNoCancellableResultData().era
            )
        }
        let dependencies = [coder, era] + timing.allOperations + rewards.allOperations + points.allOperations
        dependencies.forEach { result.addDependency($0) }
        manager.enqueue(operations: dependencies, in: .transient)
        return result
    }
}
