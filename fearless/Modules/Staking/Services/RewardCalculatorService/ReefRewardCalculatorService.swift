import Foundation
import RobinHood
import SSFUtils
import BigInt
import SSFModels

enum ReefCalculatorServiceError: Error {
    case timedOut
    case unexpectedInfo
}

final class ReefRewardCalculatorService {
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
    private var pendingRequests: [PendingRequest] = []
    private var totalStakeByEra: [EraIndex: BigUInt]?
    private var rewardPointsByEra: [EraIndex: EraRewardPoints]?
    private var validatorRewardsByEra: [EraIndex: BigUInt]?

    private let chainAsset: ChainAsset
    private let assetPrecision: Int16
    private let eraValidatorsService: EraValidatorServiceProtocol
    private let logger: LoggerProtocol?
    private let operationManager: OperationManagerProtocol
    private let providerFactory: SubstrateDataProviderFactoryProtocol
    private let storageFacade: StorageFacadeProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let stakingDurationFactory: StakingDurationOperationFactoryProtocol
    private let storageRequestPerformer: StorageRequestPerformer

    init(
        chainAsset: ChainAsset,
        assetPrecision: Int16,
        eraValidatorsService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        storageFacade: StorageFacadeProtocol,
        logger: LoggerProtocol? = nil,
        storageRequestPerformer: StorageRequestPerformer
    ) {
        self.chainAsset = chainAsset
        self.assetPrecision = assetPrecision
        self.storageFacade = storageFacade
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.eraValidatorsService = eraValidatorsService
        self.stakingDurationFactory = stakingDurationFactory
        self.chainRegistry = chainRegistry
        self.storageRequestPerformer = storageRequestPerformer
        self.logger = logger
    }

    // MARK: - Private

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RewardCalculatorEngineProtocol) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if
            let totalStakeByEra = totalStakeByEra,
            let rewardPointsByEra = rewardPointsByEra,
            let validatorRewardsByEra = validatorRewardsByEra {
            deliver(
                totalStake: totalStakeByEra,
                rewardPoints: rewardPointsByEra,
                validatorRewards: validatorRewardsByEra,
                to: request,
                chainId: chainAsset.chain.chainId,
                assetPrecision: assetPrecision
            )
        } else {
            pendingRequests.append(request)
        }
    }

    private func deliver(
        totalStake: [EraIndex: BigUInt],
        rewardPoints: [EraIndex: EraRewardPoints],
        validatorRewards: [EraIndex: BigUInt],
        to request: PendingRequest,
        chainId: ChainModel.Id,
        assetPrecision _: Int16
    ) {
        guard let runtimeCodingService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger?.error(ChainRegistryError.runtimeMetadaUnavailable.localizedDescription)
            return
        }

        let durationWrapper = stakingDurationFactory.createDurationOperation(
            from: runtimeCodingService
        )

        let eraOperation = eraValidatorsService.fetchInfoOperation()

        let mapOperation = ClosureOperation<RewardCalculatorEngineProtocol> { [weak self] in
            guard let self else {
                throw ConvenienceError(error: "Service corrupted")
            }

            let eraStakersInfo = try eraOperation.extractNoCancellableResultData()
            let stakingDuration = try durationWrapper.targetOperation.extractNoCancellableResultData()

            return ReefRewardCalculatorEngine(
                totalStakeByEra: totalStake,
                rewardPointsByEra: rewardPoints,
                validatorRewardsByEra: validatorRewards,
                validators: eraStakersInfo.validators,
                chainAsset: self.chainAsset
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

    private func notifyPendingClosures(
        with totalStake: [EraIndex: BigUInt],
        rewardPoints: [EraIndex: EraRewardPoints],
        validatorRewards: [EraIndex: BigUInt]
    ) {
        logger?.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach {
            deliver(
                totalStake: totalStake,
                rewardPoints: rewardPoints,
                validatorRewards: validatorRewards,
                to: $0,
                chainId: chainAsset.chain.chainId,
                assetPrecision: assetPrecision
            )
        }

        logger?.debug("Fulfilled pendings")
    }

    private func fetchTotalValidatorRewards() {
        let totalStakeRequest = StakingErasTotalStakeRequest()
        let rewardPointsRequest = StakingErasRewardPointsRequest()
        let validatorRewardRequest = StakingErasValidatorRewardRequest()

        Task {
            do {
                let totalStake: [String: StringScaleMapper<BigUInt>]? = try await storageRequestPerformer.performPrefix(totalStakeRequest)
                let rewardPoints: [String: EraRewardPoints]? = try await storageRequestPerformer.performPrefix(rewardPointsRequest)
                let validatorRewards: [String: StringScaleMapper<BigUInt>]? = try await storageRequestPerformer.performPrefix(validatorRewardRequest)

                let totalStakeByEra = totalStake?.keys.reduce([EraIndex: BigUInt]()) { partialResult, key in
                    var map = partialResult

                    guard let era = EraIndex(key), let value = totalStake?[key]?.value else {
                        return partialResult
                    }

                    map[era] = value

                    return map
                }

                let rewardPointsByEra = rewardPoints?.keys.reduce([EraIndex: EraRewardPoints]()) { partialResult, key in
                    var map = partialResult

                    guard let era = EraIndex(key), let points = rewardPoints?[key] else {
                        return partialResult
                    }

                    map[era] = points

                    return map
                }

                let validatorRewardsByEra = validatorRewards?.keys.reduce([EraIndex: BigUInt]()) { partialResult, key in
                    var map = partialResult

                    guard let era = EraIndex(key), let value = validatorRewards?[key]?.value else {
                        return partialResult
                    }

                    map[era] = value

                    return map
                }

                notifyPendingClosures(
                    with: totalStakeByEra.or([:]),
                    rewardPoints: rewardPointsByEra.or([:]),
                    validatorRewards: validatorRewardsByEra.or([:])
                )
            } catch {
                print("ERROR: ", error)
            }
        }
    }
}

extension ReefRewardCalculatorService: RewardCalculatorServiceProtocol {
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
        AwaitOperation { [weak self] in
            await withCheckedContinuation { continuation in
                self?.fetchInfoFactory(runCompletionIn: nil) { info in
                    continuation.resume(with: .success(info))
                }
            }
        }
    }
}
