import Foundation
import RobinHood
import SSFUtils
import SSFModels

enum EraValidatorServiceError: Error {
    case unsuppotedStoragePath(_ path: StorageCodingPath)
    case unexpectedInfo
    case missingEngine
    case requestTimedOut
}

final class EraValidatorService {
    static let queueLabelPrefix = "jp.co.fearless.recvalidators"

    private struct PendingRequest {
        let id: UUID
        let resultClosure: (Result<EraStakersInfo, Error>) -> Void
        let queue: DispatchQueue?
    }

    let syncQueue = DispatchQueue(
        label: "\(queueLabelPrefix).\(UUID().uuidString)",
        qos: .userInitiated
    )

    private(set) var activeEra: UInt32?
    private var isActive: Bool = false

    private var snapshot: EraStakersInfo?
    private var failure: Error?
    /// The active era storage item last received, read again when a request follows a failure or times out.
    var lastActiveEraItem: ChainStorageItem?
    private var lastRecoveryRead: Date?
    /// Numbers active era reads. A read that fails after a later read began reports nothing: its failure would
    /// discard the newer read's data.
    private var readGeneration = 0
    private let requestTimeout: TimeInterval
    private var eraDataProvider: StreamableProvider<ChainStorageItem>?
    private var pendingRequests: [PendingRequest] = []

    let chain: ChainModel
    let storageFacade: StorageFacadeProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol?

    var chainId: ChainModel.Id {
        chain.chainId
    }

    init(
        chain: ChainModel,
        storageFacade: StorageFacadeProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol? = nil,
        requestTimeout: TimeInterval = 60
    ) {
        self.chain = chain
        self.storageFacade = storageFacade
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.chainRegistry = chainRegistry
        self.logger = logger
        self.requestTimeout = requestTimeout
    }

    func didReceiveSnapshot(_ snapshot: EraStakersInfo) {
        logger?.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard activeEra == nil || activeEra == snapshot.activeEra else { return }
        failure = nil
        self.snapshot = snapshot

        if !pendingRequests.isEmpty {
            let requests = pendingRequests
            pendingRequests = []

            requests.forEach { deliver(result: .success(snapshot), to: $0) }

            logger?.debug("Fulfilled pendings")
        }

        DispatchQueue.main.async {
            let event = EraStakersInfoChanged()
            self.eventCenter.notify(with: event)
        }
    }

    func didReceiveActiveEra(_ era: UInt32) {
        if activeEra != era { snapshot = nil }
        failure = nil
        activeEra = era
    }

    /// Starts a new active era read and returns its number.
    func beginActiveEraRead() -> Int {
        readGeneration += 1
        return readGeneration
    }

    func isCurrentRead(_ generation: Int) -> Bool {
        generation == readGeneration
    }

    func didFail(_ error: Error, read generation: Int) {
        guard isCurrentRead(generation) else {
            logger?.warning("Ignoring the failure of a replaced era read: \(error)")
            return
        }

        didFail(error)
    }

    func didFail(_ error: Error) {
        failure = error
        snapshot = nil
        let requests = pendingRequests
        pendingRequests = []
        requests.forEach { deliver(result: .failure(error), to: $0) }
    }

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (Result<EraStakersInfo, Error>) -> Void
    ) {
        let request = PendingRequest(id: UUID(), resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(result: .success(snapshot), to: request)
        } else if let failure = failure {
            deliver(result: .failure(failure), to: request)
            // The next request starts over from the last active era rather than repeating this failure until the era
            // changes, which takes a day on Polkadot.
            self.failure = nil
            readActiveEraAgain()
        } else {
            pendingRequests.append(request)
            syncQueue.asyncAfter(deadline: .now() + requestTimeout) { [weak self] in
                guard let self = self,
                      let index = self.pendingRequests.firstIndex(where: { $0.id == request.id }) else { return }
                let timedOut = self.pendingRequests.remove(at: index)
                self.deliver(result: .failure(EraValidatorServiceError.requestTimedOut), to: timedOut)
                self.readActiveEraAgain()
            }
        }
    }

    /// Reads the last active era item again after a failure or a request that timed out, at most once per request
    /// timeout, so a lost read is retried without stacking parallel validator downloads.
    private func readActiveEraAgain() {
        guard isActive, let item = lastActiveEraItem else { return }
        let now = Date()
        if let last = lastRecoveryRead, now.timeIntervalSince(last) < requestTimeout { return }
        lastRecoveryRead = now
        didUpdateActiveEraItem(item)
    }

    private func deliver(result: Result<EraStakersInfo, Error>, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(result)
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
                self?.didFail(error)
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
            didFail(error)
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
            self.failure = nil

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
        AwaitOperation { [weak self] in
            guard let self = self else { throw BaseOperationError.parentOperationCancelled }
            return try await withCheckedThrowingContinuation { continuation in
                self.syncQueue.async {
                    self.fetchInfoFactory(runCompletionIn: nil) { result in
                        continuation.resume(with: result)
                    }
                }
            }
        }
    }
}
