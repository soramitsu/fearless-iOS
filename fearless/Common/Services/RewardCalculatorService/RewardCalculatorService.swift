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

    private let syncQueue = DispatchQueue(label: "\(queueLabelPrefix).\(UUID().uuidString)")

    private var isActive: Bool = false
    private var chain: Chain?
    private var snapshot: BigUInt?

    private var totalIssuanceDataProvider: StreamableProvider<ChainStorageItem>?
    private var pendingRequests: [PendingRequest] = []

    let eraValidatorsService: EraValidatorServiceProtocol
    let logger: LoggerProtocol
    let operationManager: OperationManagerProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol
    let storageFacade: StorageFacadeProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol

    init(eraValidatorsService: EraValidatorServiceProtocol,
         logger: LoggerProtocol,
         operationManager: OperationManagerProtocol,
         providerFactory: SubstrateDataProviderFactoryProtocol,
         runtimeCodingService: RuntimeCodingServiceProtocol,
         storageFacade: StorageFacadeProtocol) {
        self.logger = logger
        self.storageFacade = storageFacade
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.eraValidatorsService = eraValidatorsService
        self.runtimeCodingService = runtimeCodingService
    }

    // MARK: - Private
    private func fetchInfoFactory(runCompletionIn queue: DispatchQueue?,
                                  executing closure: @escaping (RewardCalculatorEngineProtocol) -> Void) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
        }
    }

    private func deliver(snapshot: BigUInt, to request: PendingRequest) {
        let eraOperation = eraValidatorsService.fetchInfoOperation()

        eraOperation.completionBlock = {
            dispatchInQueueWhenPossible(request.queue) {
                if let result = try? eraOperation.extractResultData() {
                    if let chain = self.chain {
                        let calculator = RewardCalculatorEngine(totalIssuance: Balance(value: snapshot),
                                                                validators: result.validators,
                                                                chain: chain)
                        request.resultClosure(calculator)
                    }
                }
            } }

        operationManager.enqueue(operations: [eraOperation],
                                 in: .transient)
    }

    private func notifyPendingClosures(with totalIssuance: BigUInt) {
        logger.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach { deliver(snapshot: totalIssuance, to: $0) }

        logger.debug("Fulfilled pendings")
    }

    private func handleTotalIssuanceDecodingResult(chain: Chain, result: Result<String, Error>?) {
        guard chain == self.chain else {
            Logger.shared.warning("Total Issuance decoding triggered but chain changed. Cancelled.")
            return
        }

        switch result {
        case .success(let totalIssuance):
            let value = BigUInt(totalIssuance)!
            self.snapshot = value
            notifyPendingClosures(with: value)
        case .failure(let error):
            logger.error("Did receive total issuance decoding error: \(error)")
        case .none:
            logger.warning("Error decoding operation canceled")
        }
    }

    private func didUpdateTotalIssuanceItem(_ totalIssuanceItem: ChainStorageItem?) {
        guard let chain = chain else {
            logger.warning("Missing chain to proccess total issuance")
            return
        }

        guard let totalIssuanceItem = totalIssuanceItem else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<String>(path: .totalIssuance,
                                                                 data: totalIssuanceItem.data)
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
                self?.handleTotalIssuanceDecodingResult(chain: chain, result: decodingOperation.result)
            }
        }

        operationManager.enqueue(operations: [codingFactoryOperation, decodingOperation],
                                 in: .transient)
    }

    private func subscribe() {
        do {
            guard let chain = self.chain else {
                Logger.shared.warning("Missing chain to subscribe")
                return
            }

            let localFactory = try ChainStorageIdFactory(chain: chain)

            let path = StorageCodingPath.totalIssuance
            let key = try StorageKeyFactory().createStorageKey(moduleName: path.moduleName,
                                                               storageName: path.itemName)

            let localKey = localFactory.createIdentifier(for: key)
            let totalIssuanceDataProvider = providerFactory.createStorageProvider(for: localKey)

            let updateClosure: ([DataProviderChange<ChainStorageItem>]) -> Void = { [weak self] changes in
                let finalValue: ChainStorageItem? = changes.reduce(nil) { (_, item) in
                    switch item {
                    case .insert(let newItem), .update(let newItem):
                        return newItem
                    case .delete:
                        return nil
                    }
                }

                self?.didUpdateTotalIssuanceItem(finalValue)
            }

            let failureClosure: (Error) -> Void = { [weak self] (error) in
                self?.logger.error("Did receive error: \(error)")
            }

            totalIssuanceDataProvider.addObserver(self,
                                                  deliverOn: syncQueue,
                                                  executing: updateClosure,
                                                  failing: failureClosure,
                                                  options: StreamableProviderObserverOptions())

            self.totalIssuanceDataProvider = totalIssuanceDataProvider
        } catch {
            logger.error("Can't make subscription")
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

    func update(to chain: Chain) {
        syncQueue.async {
            if self.isActive {
                self.unsubscribe()
            }

            self.snapshot = nil
            self.chain = chain

            if self.isActive {
                self.subscribe()
            }
        }
    }

    func fetchCalculatorOperation(with timeout: TimeInterval) -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation {
            var fetchedInfo: RewardCalculatorEngineProtocol?

            let semaphore = DispatchSemaphore(value: 0)

            self.syncQueue.async {
                self.fetchInfoFactory(runCompletionIn: nil) { [weak semaphore] info in
                    fetchedInfo = info
                    semaphore?.signal()
                }
            }

            let result = semaphore.wait(timeout: DispatchTime.now() + .milliseconds(timeout.milliseconds))

            switch result {
            case .success:
                guard let info = fetchedInfo else {
                    throw RewardCalculatorServiceError.unexpectedInfo
                }

                return info
            case .timedOut:
                throw RewardCalculatorServiceError.timedOut
            }
        }
    }
}
