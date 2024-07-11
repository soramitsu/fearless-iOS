import Foundation
import RobinHood
import SSFUtils
import BigInt
import SSFModels
import SSFStorageQueryKit

enum SoraCalculatorServiceError: Error {
    case timedOut
    case unexpectedInfo
}

final class SoraRewardCalculatorService {
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
    private var rewardChainAsset: ChainAsset?
    private var polkaswapRemoteSettings: PolkaswapRemoteSettings?
    private var dexIds: [UInt32] = []
    private var marketSource: SwapMarketSourceProtocol?
    private var totalStakeByEra: [EraIndex: BigUInt]?
    private var rewardPointsByEra: [EraIndex: EraRewardPoints]?
    private var validatorRewardsByEra: [EraIndex: BigUInt]?

    private var swapValues: [SwapValues] = []
    private var swapValueErrors: [Error] = []
    private var dexInfos: [PolkaswapDexInfo] = []
    private var rewardAssetRate: Decimal?

    private var pendingRequests: [PendingRequest] = []

    private let chainAsset: ChainAsset
    private let assetPrecision: Int16
    private let eraValidatorsService: EraValidatorServiceProtocol
    private let logger: LoggerProtocol?
    private let operationManager: OperationManagerProtocol
    private let providerFactory: SubstrateDataProviderFactoryProtocol
    private let storageFacade: StorageFacadeProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let stakingDurationFactory: StakingDurationOperationFactoryProtocol
    private let polkaswapOperationFactory: PolkaswapOperationFactoryProtocol
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let settingsRepository: AnyDataProviderRepository<PolkaswapRemoteSettings>
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let storageRequestPerformer: SSFStorageQueryKit.StorageRequestPerformer

    init(
        chainAsset: ChainAsset,
        assetPrecision: Int16,
        eraValidatorsService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        storageFacade: StorageFacadeProtocol,
        polkaswapOperationFactory: PolkaswapOperationFactoryProtocol,
        chainAssetFetching: ChainAssetFetchingProtocol,
        settingsRepository: AnyDataProviderRepository<PolkaswapRemoteSettings>,
        logger: LoggerProtocol? = nil,
        storageRequestFactory: StorageRequestFactoryProtocol,
        storageRequestPerformer: SSFStorageQueryKit.StorageRequestPerformer
    ) {
        self.chainAsset = chainAsset
        self.assetPrecision = assetPrecision
        self.storageFacade = storageFacade
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.eraValidatorsService = eraValidatorsService
        self.stakingDurationFactory = stakingDurationFactory
        self.chainRegistry = chainRegistry
        self.polkaswapOperationFactory = polkaswapOperationFactory
        self.chainAssetFetching = chainAssetFetching
        self.settingsRepository = settingsRepository
        self.logger = logger
        self.storageRequestFactory = storageRequestFactory
        self.storageRequestPerformer = storageRequestPerformer
    }

    // MARK: - Polkaswap quoutes

    private func fetchQuotes() {
        guard let swapToChainAsset = rewardChainAsset,
              let swapFromAssetId = chainAsset.asset.currencyId,
              let swapToAssetId = swapToChainAsset.asset.currencyId,
              let marketSourcer = marketSource
        else {
            return
        }

        let amount: BigUInt = 1_000_000_000_000_000_000
        let amountString = String(amount)

        let quoteParams = PolkaswapQuoteParams(
            fromAssetId: swapFromAssetId,
            toAssetId: swapToAssetId,
            amount: amountString,
            swapVariant: .desiredInput,
            liquiditySources: marketSourcer.getRemoteMarketSources(),
            filterMode: LiquiditySourceType.smart.filterMode
        )

        swapValues.removeAll()
        swapValueErrors.removeAll()
        dexInfos.removeAll()
        var allOperations: [Operation] = []
        let group = DispatchGroup()

        dexIds.forEach { dexId in
            group.enter()
            let quotesOperation = polkaswapOperationFactory
                .createPolkaswapQuoteOperation(dexId: dexId, params: quoteParams)

            quotesOperation.completionBlock = { [weak self, dexId, group] in
                guard let strongSelf = self else { return }
                DispatchQueue.global().sync(flags: .barrier) {
                    do {
                        var result = try quotesOperation.extractNoCancellableResultData()
                        result.dexId = dexId
                        strongSelf.swapValues.append(result)
                    } catch {
                        strongSelf.swapValueErrors.append(error)
                    }
                    group.leave()
                }
            }
            allOperations.append(quotesOperation)
        }
        operationManager.enqueue(operations: allOperations, in: .blockAfter)

        let workItem = DispatchWorkItem(flags: .barrier) { [weak self] in
            let rewardAssetAmount = self?.swapValues.compactMap { BigUInt(string: $0.amount) }.max()
            guard
                let rewardAssetAmount = rewardAssetAmount,
                let rewardChainAsset = self?.rewardChainAsset,
                let stakingChainAsset = self?.chainAsset,
                let stakingAmountDecimal = Decimal.fromSubstrateAmount(amount, precision: Int16(stakingChainAsset.asset.precision)),
                let receivedAmountDecimal = Decimal.fromSubstrateAmount(rewardAssetAmount, precision: Int16(rewardChainAsset.asset.precision))
            else {
                return
            }

            self?.rewardAssetRate = receivedAmountDecimal / stakingAmountDecimal

            self?.fetchTotalValidatorRewards()
        }

        group.notify(queue: .main, work: workItem)
    }

    private func fetchPolkaswapSettings() {
        let operation = settingsRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            do {
                guard let settings = try operation.extractNoCancellableResultData().first else {
                    return
                }

                self?.polkaswapRemoteSettings = settings
                self?.dexIds = settings.availableDexIds.map { $0.code }

                self?.marketSource = SwapMarketSource(
                    fromAssetId: self?.chainAsset.asset.currencyId,
                    toAssetId: self?.rewardChainAsset?.asset.currencyId,
                    remoteSettings: settings
                )

                self?.marketSource?.didLoad([.smart])

                self?.fetchQuotes()
            } catch {
                self?.logger?.error(error.localizedDescription)
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    private func fetchRewardChainAsset() {
        guard let assetName = chainAsset.chain.stakingSettings?.rewardAssetName else {
            return
        }

        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [.assetName(assetName), .chainId(chainAsset.chain.chainId)],
            sortDescriptors: []
        ) { [weak self] result in
            switch result {
            case let .success(chainAssets):
                let rewardChainAsset = chainAssets.first(where: { $0.asset.symbol.lowercased() == assetName.lowercased() })
                self?.rewardChainAsset = rewardChainAsset

                self?.fetchPolkaswapSettings()
            case let .failure(error):
                self?.logger?.error(error.localizedDescription)
            case .none:
                break
            }
        }
    }

    // MARK: - Private

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RewardCalculatorEngineProtocol) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let totalStake = totalStakeByEra, let rewardPoints = rewardPointsByEra, let validatorRewards = validatorRewardsByEra {
            deliver(totalStake: totalStake, rewardPoints: rewardPoints, validatorRewards: validatorRewards, to: request)
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
        guard let runtimeCodingService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
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

            return SoraRewardCalculatorEngine(
                totalStakeByEra: totalStake,
                rewardPointsByEra: rewardPoints,
                validatorRewardsByEra: validatorRewards,
                validators: eraStakersInfo.validators,
                chainAsset: self.chainAsset,
                eraDurationInSeconds: stakingDuration.era,
                rewardAssetRate: self.rewardAssetRate.or(1.0)
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

extension SoraRewardCalculatorService: RewardCalculatorServiceProtocol {
    func setup() {
        eraValidatorsService.setup()
        fetchRewardChainAsset()

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
