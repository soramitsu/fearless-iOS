import Foundation
import RobinHood
import SSFUtils
import BigInt
import SSFModels

enum PortionCalculatorServiceError: Error {
    case timedOut
    case unexpectedInfo
}

final class PortionRewardCalculatorService {
    static let queueLabelPrefix = "jp.co.fearless.rewcalculator"

    private struct PendingRequest {
        let resultClosure: (RewardCalculatorEngineProtocol) -> Void
        let queue: DispatchQueue?
    }

    private let syncQueue = DispatchQueue(
        label: "\(queueLabelPrefix).\(UUID().uuidString)",
        qos: .userInitiated
    )

    private var isActive: Bool = false
    private var snapshot: BigUInt?
    private var pendingRequests: [PendingRequest] = []

    private let chainAsset: ChainAsset
    private let assetPrecision: Int16
    private let eraValidatorsService: EraValidatorServiceProtocol
    private let logger: LoggerProtocol?
    private let operationManager: OperationManagerProtocol
    private let providerFactory: SubstrateDataProviderFactoryProtocol
    private let storageFacade: StorageFacadeProtocol
    private let runtimeCodingService: RuntimeCodingServiceProtocol
    private let stakingDurationFactory: StakingDurationOperationFactoryProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let engine: JSONRPCEngine

    init(
        chainAsset: ChainAsset,
        assetPrecision: Int16,
        eraValidatorsService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        storageFacade: StorageFacadeProtocol,
        engine: JSONRPCEngine,
        storageRequestFactory: StorageRequestFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.chainAsset = chainAsset
        self.assetPrecision = assetPrecision
        self.storageFacade = storageFacade
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.eraValidatorsService = eraValidatorsService
        self.stakingDurationFactory = stakingDurationFactory
        self.runtimeCodingService = runtimeCodingService
        self.engine = engine
        self.storageRequestFactory = storageRequestFactory
        self.logger = logger
    }

    // MARK: - Private

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RewardCalculatorEngineProtocol) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request, chainId: chainAsset.chain.chainId, assetPrecision: assetPrecision)
        } else {
            pendingRequests.append(request)
        }
    }

    private func deliver(
        snapshot: BigUInt,
        to request: PendingRequest,
        chainId: ChainModel.Id,
        assetPrecision: Int16
    ) {
        let durationWrapper = stakingDurationFactory.createDurationOperation(
            from: runtimeCodingService
        )

        let eraOperation = eraValidatorsService.fetchInfoOperation()

        let mapOperation = ClosureOperation<RewardCalculatorEngineProtocol> {
            let eraStakersInfo = try eraOperation.extractNoCancellableResultData()
            let stakingDuration = try durationWrapper.targetOperation.extractNoCancellableResultData()

            return PortionRewardCalculatorEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                averageTotalRewardsPerEra: snapshot,
                validators: eraStakersInfo.validators,
                eraDurationInSeconds: stakingDuration.era
            )
        }

        mapOperation.addDependency(durationWrapper.targetOperation)
        mapOperation.addDependency(eraOperation)

        mapOperation.completionBlock = { [weak self] in
            dispatchInQueueWhenPossible(request.queue) {
                switch mapOperation.result {
                case let .success(calculator):
                    request.resultClosure(calculator)
                case let .failure(error):
                    self?.logger?.error("Era stakers info fetch error: \(error)")
                case .none:
                    self?.logger?.warning("Era stakers info fetch cancelled")
                }
            }
        }

        operationManager.enqueue(
            operations: durationWrapper.allOperations + [eraOperation, mapOperation],
            in: .transient
        )
    }

    private func notifyPendingClosures(with eraValBurned: BigUInt) {
        logger?.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach {
            deliver(
                snapshot: eraValBurned,
                to: $0,
                chainId: chainAsset.chain.chainId,
                assetPrecision: assetPrecision
            )
        }

        logger?.debug("Fulfilled pendings")
    }

    private func createTotalValidatorRewardsOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> {
        let totalValidatorRewardsWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> =
            storageRequestFactory.queryItemsByPrefix(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .totalValidatorReward)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .totalValidatorReward
            )

        totalValidatorRewardsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return CompoundOperationWrapper(targetOperation: totalValidatorRewardsWrapper.targetOperation, dependencies: [runtimeOperation] + totalValidatorRewardsWrapper.dependencies)
    }

    private func fetchTotalValidatorRewards() {
        let runtimeOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let totalValidatorRewardsOperation = createTotalValidatorRewardsOperation(dependingOn: runtimeOperation)

        totalValidatorRewardsOperation.targetOperation.completionBlock = { [weak self] in
            do {
                let result = try totalValidatorRewardsOperation.targetOperation.extractNoCancellableResultData()

                let values = result.compactMap { $0.value?.value }
                let averageTotalValidatorReward = values.reduce(BigUInt.zero, +) / BigUInt(result.count)

                self?.snapshot = averageTotalValidatorReward
                self?.notifyPendingClosures(with: averageTotalValidatorReward)
            } catch {
                self?.logger?.error("Error on fetching total validator rewards: \(error)")
            }
        }

        operationManager.enqueue(operations: totalValidatorRewardsOperation.allOperations, in: .transient)
    }
}

extension PortionRewardCalculatorService: RewardCalculatorServiceProtocol {
    func setup() {
        eraValidatorsService.setup()
        fetchTotalValidatorRewards()

        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = true
        }
    }

    func throttle() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = false
        }
    }

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation {
            var fetchedInfo: RewardCalculatorEngineProtocol?

            let semaphore = DispatchSemaphore(value: 0)

            let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.fetchCalculator.\(self.chainAsset.chain.chainId)", qos: .userInitiated)

            self.syncQueue.async {
                self.fetchInfoFactory(runCompletionIn: queue) { [weak semaphore] info in
                    fetchedInfo = info
                    semaphore?.signal()
                }
            }

            semaphore.wait()

            guard let info = fetchedInfo else {
                throw RewardCalculatorServiceError.unexpectedInfo
            }

            return info
        }
    }
}
