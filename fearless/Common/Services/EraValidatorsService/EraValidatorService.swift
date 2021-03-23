import Foundation
import RobinHood
import FearlessUtils

enum EraValidatorServiceError: Error {
    case unsuppotedStoragePath(_ path: StorageCodingPath)
    case timedOut
    case unexpectedInfo
    case missingEngine
}

final class EraValidatorService {
    static let queueLabelPrefix = "jp.co.fearless.recvalidators"

    private struct PendingRequest {
        let resultClosure: (EraStakersInfo) -> Void
        let queue: DispatchQueue?
    }

    let syncQueue = DispatchQueue(label: "\(queueLabelPrefix).\(UUID().uuidString)",
                                  qos: .userInitiated)

    private(set) var activeEra: UInt32?
    private(set) var chain: Chain?
    private(set) var engine: JSONRPCEngine?
    private var isActive: Bool = false

    private var snapshot: EraStakersInfo?
    private var eraDataProvider: StreamableProvider<ChainStorageItem>?

    let storageFacade: StorageFacadeProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol
    private var pendingRequests: [PendingRequest] = []
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol?

    init(storageFacade: StorageFacadeProtocol,
         runtimeCodingService: RuntimeCodingServiceProtocol,
         providerFactory: SubstrateDataProviderFactoryProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol,
         logger: LoggerProtocol? = nil) {
        self.storageFacade = storageFacade
        self.runtimeCodingService = runtimeCodingService
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func didReceiveSnapshot(_ snapshot: EraStakersInfo) {
        logger?.debug("Attempt fulfill pendings \(pendingRequests.count)")

        self.snapshot = snapshot

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach { deliver(snapshot: snapshot, to: $0) }

        DispatchQueue.main.async {
            let event = EraStakersInfoChanged()
            self.eventCenter.notify(with: event)
        }

        logger?.debug("Fulfilled pendings")
    }

    func didReceiveActiveEra(_ era: UInt32) {
        self.activeEra = era
    }

    private func fetchInfoFactory(runCompletionIn queue: DispatchQueue?,
                                  executing closure: @escaping (EraStakersInfo) -> Void) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
        }
    }

    private func deliver(snapshot: EraStakersInfo, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(snapshot)
        }
    }

    private func subscribe() {
        do {
            guard let chain = self.chain else {
                logger?.warning("Missing chain to subscribe")
                return
            }

            let localFactory = try ChainStorageIdFactory(chain: chain)

            let path = StorageCodingPath.activeEra
            let key = try StorageKeyFactory().createStorageKey(moduleName: path.moduleName,
                                                               storageName: path.itemName)

            let localKey = localFactory.createIdentifier(for: key)
            let eraDataProvider = providerFactory.createStorageProvider(for: localKey)

            let updateClosure: ([DataProviderChange<ChainStorageItem>]) -> Void = { [weak self] changes in
                let finalValue: ChainStorageItem? = changes.reduce(nil) { (_, item) in
                    switch item {
                    case .insert(let newItem), .update(let newItem):
                        return newItem
                    case .delete:
                        return nil
                    }
                }

                self?.didUpdateActiveEraItem(finalValue)
            }

            let failureClosure: (Error) -> Void = { [weak self] (error) in
                self?.logger?.error("Did receive error: \(error)")
            }

            eraDataProvider.addObserver(self,
                                        deliverOn: syncQueue,
                                        executing: updateClosure,
                                        failing: failureClosure,
                                        options: StreamableProviderObserverOptions.substrateSource())

            self.eraDataProvider = eraDataProvider
        } catch {
            logger?.error("Can't make subscription")
        }
    }

    private func unsubscribe() {
        eraDataProvider?.removeObserver(self)
        eraDataProvider = nil
    }
}

extension EraValidatorService: EraValidatorServiceProtocol {
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

    func update(to chain: Chain, engine: JSONRPCEngine) {
        syncQueue.async {
            if self.isActive {
                self.unsubscribe()
            }

            self.snapshot = nil
            self.activeEra = nil
            self.engine = engine
            self.chain = chain

            if self.isActive {
                self.subscribe()
            }
        }
    }

    func fetchInfoOperation(with timeout: TimeInterval) -> BaseOperation<EraStakersInfo> {
        ClosureOperation {
            var fetchedInfo: EraStakersInfo?

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
                    throw EraValidatorServiceError.unexpectedInfo
                }

                return info
            case .timedOut:
                throw EraValidatorServiceError.timedOut
            }
        }
    }
}
