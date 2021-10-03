import Foundation
import RobinHood
import FearlessUtils
import BigInt

enum RewardCalculatorServiceError: Error {
    case timedOut
    case unexpectedInfo
}

final class RewardCalculatorService {
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

    private var totalIssuanceDataProvider: StreamableProvider<ChainStorageItem>?
    private var pendingRequests: [PendingRequest] = []

    let chainId: ChainModel.Id
    let assetPrecision: Int16
    let eraValidatorsService: EraValidatorServiceProtocol
    let logger: LoggerProtocol?
    let operationManager: OperationManagerProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol
    let storageFacade: StorageFacadeProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let stakingDurationFactory: StakingDurationOperationFactoryProtocol

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        eraValidatorsService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        storageFacade: StorageFacadeProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.chainId = chainId
        self.assetPrecision = assetPrecision
        self.storageFacade = storageFacade
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.eraValidatorsService = eraValidatorsService
        self.stakingDurationFactory = stakingDurationFactory
        self.runtimeCodingService = runtimeCodingService
        self.logger = logger
    }

    // MARK: - Private

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RewardCalculatorEngineProtocol) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request, chainId: chainId, assetPrecision: assetPrecision)
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

        let mapOperation = ClosureOperation<RewardCalculatorEngine> {
            let eraStakersInfo = try eraOperation.extractNoCancellableResultData()
            let stakingDuration = try durationWrapper.targetOperation.extractNoCancellableResultData()

            return RewardCalculatorEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                totalIssuance: snapshot,
                validators: eraStakersInfo.validators,
                eraDurationInSeconds: stakingDuration.era
            )
        }

        mapOperation.addDependency(durationWrapper.targetOperation)
        mapOperation.addDependency(eraOperation)

        mapOperation.completionBlock = {
            dispatchInQueueWhenPossible(request.queue) {
                switch mapOperation.result {
                case let .success(calculator):
                    request.resultClosure(calculator)
                case let .failure(error):
                    self.logger?.error("Era stakers info fetch error: \(error)")
                case .none:
                    self.logger?.warning("Era stakers info fetch cancelled")
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
                chainId: chainId,
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
                chainId: chainId
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

extension RewardCalculatorService: RewardCalculatorServiceProtocol {
    func setup() {
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

            self.syncQueue.async {
                self.fetchInfoFactory(runCompletionIn: nil) { [weak semaphore] info in
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
