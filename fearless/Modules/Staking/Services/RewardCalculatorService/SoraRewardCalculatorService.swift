import Foundation
import RobinHood
import FearlessUtils
import BigInt

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

    private var totalIssuanceDataProvider: StreamableProvider<ChainStorageItem>?
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
    private let polkaswapOperationFactory: PolkaswapOperationFactoryProtocol
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let settingsRepository: AnyDataProviderRepository<PolkaswapRemoteSettings>

    init(
        chainAsset: ChainAsset,
        assetPrecision: Int16,
        eraValidatorsService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        storageFacade: StorageFacadeProtocol,
        polkaswapOperationFactory: PolkaswapOperationFactoryProtocol,
        chainAssetFetching: ChainAssetFetchingProtocol,
        settingsRepository: AnyDataProviderRepository<PolkaswapRemoteSettings>,
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
        self.polkaswapOperationFactory = polkaswapOperationFactory
        self.chainAssetFetching = chainAssetFetching
        self.settingsRepository = settingsRepository
        self.logger = logger
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

            self?.rewardAssetRate = stakingAmountDecimal / receivedAmountDecimal
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
                let rewardChainAsset = chainAssets.first(where: { $0.asset.name.lowercased() == assetName.lowercased() })
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
        let durationWrapper = stakingDurationFactory.createDurationOperation(
            from: runtimeCodingService
        )

        let eraOperation = eraValidatorsService.fetchInfoOperation()

        let mapOperation = ClosureOperation<RewardCalculatorEngineProtocol> { [weak self] in
            let eraStakersInfo = try eraOperation.extractNoCancellableResultData()
            let stakingDuration = try durationWrapper.targetOperation.extractNoCancellableResultData()

            return RewardCalculatorEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                totalIssuance: snapshot,
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

    private func notifyPendingClosures(with totalIssuance: BigUInt) {
        logger?.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach {
            deliver(
                snapshot: totalIssuance,
                to: $0,
                chainId: chainAsset.chain.chainId,
                assetPrecision: assetPrecision
            )
        }

        logger?.debug("Fulfilled pendings")
    }

    private func handleTotalIssuanceDecodingResult(
        result: Result<StringScaleMapper<BigUInt>, Error>?
    ) {
        switch result {
        case let .success(totalIssuance):
            snapshot = totalIssuance.value
            notifyPendingClosures(with: totalIssuance.value)
        case let .failure(error):
            logger?.error("Did receive total issuance decoding error: \(error)")
        case .none:
            logger?.warning("Error decoding operation canceled")
        }
    }

    private func didUpdateTotalIssuanceItem(_ totalIssuanceItem: ChainStorageItem?) {
        guard let totalIssuanceItem = totalIssuanceItem else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation =
            StorageDecodingOperation<StringScaleMapper<BigUInt>>(
                path: .totalIssuance,
                data: totalIssuanceItem.data
            )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                self?.handleTotalIssuanceDecodingResult(result: decodingOperation.result)
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }

    private func subscribe() {
        do {
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                .totalIssuance,
                chainId: chainAsset.chain.chainId
            )

            let totalIssuanceDataProvider = providerFactory.createStorageProvider(for: localKey)

            let updateClosure: ([DataProviderChange<ChainStorageItem>]) -> Void = { [weak self] changes in
                let finalValue: ChainStorageItem? = changes.reduce(nil) { _, item in
                    switch item {
                    case let .insert(newItem), let .update(newItem):
                        return newItem
                    case .delete:
                        return nil
                    }
                }

                self?.didUpdateTotalIssuanceItem(finalValue)
            }

            let failureClosure: (Error) -> Void = { [weak self] error in
                self?.logger?.error("Did receive error: \(error)")
            }

            totalIssuanceDataProvider.addObserver(
                self,
                deliverOn: syncQueue,
                executing: updateClosure,
                failing: failureClosure,
                options: StreamableProviderObserverOptions.substrateSource()
            )

            self.totalIssuanceDataProvider = totalIssuanceDataProvider
        } catch {
            logger?.error("Can't make subscription")
        }
    }

    private func unsubscribe() {
        totalIssuanceDataProvider?.removeObserver(self)
        totalIssuanceDataProvider = nil
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

            self.subscribe()
        }
    }

    func throttle() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = false

            self.unsubscribe()
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
