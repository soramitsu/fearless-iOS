import Foundation
import RobinHood
import SSFUtils
import BigInt
import SSFModels

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
        storageRequestFactory: StorageRequestFactoryProtocol
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
            let rewardAssetAmount = self?.swapValues.compactMap { BigUInt($0.amount) }.max()
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

        chainAssetFetching.fetch(filters: [.assetName(assetName), .chainId(chainAsset.chain.chainId)], sortDescriptors: []) { [weak self] result in
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
        guard let runtimeCodingService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            logger?.error(ChainRegistryError.runtimeMetadaUnavailable.localizedDescription)
            return
        }

        let durationWrapper = stakingDurationFactory.createDurationOperation(
            from: runtimeCodingService
        )

        let eraOperation = eraValidatorsService.fetchInfoOperation()

        let mapOperation = ClosureOperation<RewardCalculatorEngineProtocol> { [weak self] in
            let eraStakersInfo = try eraOperation.extractNoCancellableResultData()
            let stakingDuration = try durationWrapper.targetOperation.extractNoCancellableResultData()

            return SoraRewardCalculatorEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                averageTotalRewardsPerEra: snapshot,
                validators: eraStakersInfo.validators,
                eraDurationInSeconds: stakingDuration.era,
                rewardAssetRate: self?.rewardAssetRate ?? 1.0
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
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }
        let totalValidatorRewardsWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]> =
            storageRequestFactory.queryItemsByPrefix(
                engine: connection,
                keys: { [try StorageKeyFactory().key(from: .totalValidatorReward)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .totalValidatorReward
            )

        totalValidatorRewardsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return CompoundOperationWrapper(targetOperation: totalValidatorRewardsWrapper.targetOperation, dependencies: [runtimeOperation] + totalValidatorRewardsWrapper.dependencies)
    }

    private func fetchTotalValidatorRewards() {
        guard let runtimeCodingService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            logger?.error(ChainRegistryError.runtimeMetadaUnavailable.localizedDescription)
            return
        }

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
