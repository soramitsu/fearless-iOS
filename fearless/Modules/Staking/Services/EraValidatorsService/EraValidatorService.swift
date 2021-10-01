import Foundation
import RobinHood
import FearlessUtils

enum EraValidatorServiceError: Error {
    case unsuppotedStoragePath(_ path: StorageCodingPath)
    case unexpectedInfo
    case missingEngine
}

final class EraValidatorService {
    static let queueLabelPrefix = "jp.co.fearless.recvalidators"

    private struct PendingRequest {
        let resultClosure: (EraStakersInfo) -> Void
        let queue: DispatchQueue?
    }

    let syncQueue = DispatchQueue(
        label: "\(queueLabelPrefix).\(UUID().uuidString)",
        qos: .userInitiated
    )

    private(set) var activeEra: UInt32?
    private var isActive: Bool = false

    private var snapshot: EraStakersInfo?
    private var eraDataProvider: StreamableProvider<ChainStorageItem>?
    private var pendingRequests: [PendingRequest] = []

    let chainId: ChainModel.Id
    let storageFacade: StorageFacadeProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let providerFactory: SubstrateDataProviderFactoryProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol?

    init(
        chainId: ChainModel.Id,
        storageFacade: StorageFacadeProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.chainId = chainId
        self.storageFacade = storageFacade
        self.runtimeCodingService = runtimeCodingService
        self.connection = connection
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func didReceiveSnapshot(_ snapshot: EraStakersInfo) {
        logger?.debug("Attempt fulfill pendings \(pendingRequests.count)")

        self.snapshot = snapshot

        if !pendingRequests.isEmpty {
            let requests = pendingRequests
            pendingRequests = []

            requests.forEach { deliver(snapshot: snapshot, to: $0) }

            logger?.debug("Fulfilled pendings")
        }

        DispatchQueue.main.async {
            let event = EraStakersInfoChanged()
            self.eventCenter.notify(with: event)
        }
    }

    func didReceiveActiveEra(_ era: UInt32) {
        activeEra = era
    }

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (EraStakersInfo) -> Void
    ) {
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
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(.activeEra, chainId: chainId)
            let eraDataProvider = providerFactory.createStorageProvider(for: localKey)

            let updateClosure: ([DataProviderChange<ChainStorageItem>]) -> Void = { [weak self] changes in
                let finalValue: ChainStorageItem? = changes.reduce(nil) { _, item in
                    switch item {
                    case let .insert(newItem), let .update(newItem):
                        return newItem
                    case .delete:
                        return nil
                    }
                }

                self?.didUpdateActiveEraItem(finalValue)
            }

            let failureClosure: (Error) -> Void = { [weak self] error in
                self?.logger?.error("Did receive error: \(error)")
            }

            eraDataProvider.addObserver(
                self,
                deliverOn: syncQueue,
                executing: updateClosure,
                failing: failureClosure,
                options: StreamableProviderObserverOptions.substrateSource()
            )

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

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        ClosureOperation {
            var fetchedInfo: EraStakersInfo?

            let semaphore = DispatchSemaphore(value: 0)

            self.syncQueue.async {
                self.fetchInfoFactory(runCompletionIn: nil) { [weak semaphore] info in
                    fetchedInfo = info
                    semaphore?.signal()
                }
            }

            semaphore.wait()

            guard let info = fetchedInfo else {
                throw EraValidatorServiceError.unexpectedInfo
            }

            return info
        }
    }
}
