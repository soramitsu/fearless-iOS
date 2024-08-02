import Foundation
import RobinHood
import SSFUtils
import BigInt
import SSFModels
import SSFStorageQueryKit

enum ReefCalculatorServiceError: Error {
    case timeout
    case unexpectedInfo
}

final class ReefRewardCalculatorService {
    private struct PendingRequest {
        let resultClosure: (RewardCalculatorEngineProtocol) -> Void
        let queue: DispatchQueue?
    }

    private var isActive: Bool = false
    private var pendingRequests: [PendingRequest] = []
    private var totalStakeByEra: [EraIndex: BigUInt]?
    private var rewardPointsByEra: [EraIndex: EraRewardPoints]?
    private var validatorRewardsByEra: [EraIndex: BigUInt]?

    private let chainAsset: ChainAsset
    private let eraValidatorsService: EraValidatorServiceProtocol
    private let logger: LoggerProtocol?
    private let operationManager: OperationManagerProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let storageRequestPerformer: SSFStorageQueryKit.StorageRequestPerformer

    init(
        chainAsset: ChainAsset,
        eraValidatorsService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol? = nil,
        storageRequestPerformer: SSFStorageQueryKit.StorageRequestPerformer
    ) {
        self.chainAsset = chainAsset
        self.operationManager = operationManager
        self.eraValidatorsService = eraValidatorsService
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
                to: request
            )
        } else {
            pendingRequests.append(request)
        }
    }

    private func deliver(
        totalStake: [EraIndex: BigUInt],
        rewardPoints: [EraIndex: EraRewardPoints],
        validatorRewards: [EraIndex: BigUInt],
        to request: PendingRequest
    ) {
        let eraOperation = eraValidatorsService.fetchInfoOperation()

        let mapOperation = ClosureOperation<RewardCalculatorEngineProtocol> { [weak self] in
            guard let self else {
                throw ConvenienceError(error: "Service corrupted")
            }

            let eraStakersInfo = try eraOperation.extractNoCancellableResultData()

            return ReefRewardCalculatorEngine(
                totalStakeByEra: totalStake,
                rewardPointsByEra: rewardPoints,
                validatorRewardsByEra: validatorRewards,
                validators: eraStakersInfo.validators,
                chainAsset: self.chainAsset
            )
        }

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
            operations: [eraOperation, mapOperation],
            in: .transient
        )
    }

    private func notifyPendingClosures(
        with totalStake: [EraIndex: BigUInt],
        rewardPoints: [EraIndex: EraRewardPoints],
        validatorRewards: [EraIndex: BigUInt]
    ) {
        guard pendingRequests.isNotEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach {
            deliver(
                totalStake: totalStake,
                rewardPoints: rewardPoints,
                validatorRewards: validatorRewards,
                to: $0
            )
        }
    }

    private func fetchTotalValidatorRewards() {
        let totalStakeRequest = StakingErasTotalStakeRequest()
        let rewardPointsRequest = StakingErasRewardPointsRequest()
        let validatorRewardRequest = StakingErasValidatorRewardRequest()

        Task {
            do {
                async let totalStake: [String: StringScaleMapper<BigUInt>]? = try await storageRequestPerformer.performPrefix(totalStakeRequest, chain: chainAsset.chain)
                async let rewardPoints: [String: EraRewardPoints]? = try await storageRequestPerformer.performPrefix(rewardPointsRequest, chain: chainAsset.chain)
                async let validatorRewards: [String: StringScaleMapper<BigUInt>]? = try await storageRequestPerformer.performPrefix(validatorRewardRequest, chain: chainAsset.chain)

                let totalStakeValue = try await totalStake
                let totalStakeByEra = totalStakeValue?.keys.reduce([EraIndex: BigUInt]()) { partialResult, key in
                    var map = partialResult

                    guard let era = EraIndex(key), let value = totalStakeValue?[key]?.value else {
                        return partialResult
                    }

                    map[era] = value

                    return map
                }

                let rewardPointsValue = try await rewardPoints
                let rewardPointsByEra = rewardPointsValue?.keys.reduce([EraIndex: EraRewardPoints]()) { partialResult, key in
                    var map = partialResult

                    guard let era = EraIndex(key), let points = rewardPointsValue?[key] else {
                        return partialResult
                    }

                    map[era] = points

                    return map
                }

                let validatorRewardsValue = try await validatorRewards
                let validatorRewardsByEra = validatorRewardsValue?.keys.reduce([EraIndex: BigUInt]()) { partialResult, key in
                    var map = partialResult

                    guard let era = EraIndex(key), let value = validatorRewardsValue?[key]?.value else {
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
                logger?.error(error.localizedDescription)
            }
        }
    }
}

extension ReefRewardCalculatorService: RewardCalculatorServiceProtocol {
    func setup() {
        eraValidatorsService.setup()
        fetchTotalValidatorRewards()

        guard !isActive else {
            return
        }

        isActive = true
    }

    func throttle() {
        guard !isActive else {
            return
        }

        isActive = false
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
