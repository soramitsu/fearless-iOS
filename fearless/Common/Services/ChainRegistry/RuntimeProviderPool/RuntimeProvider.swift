import Foundation
import RobinHood
import SSFUtils

// swiftlint:disable file_length
protocol RuntimeProviderProtocol: AnyObject, RuntimeCodingServiceProtocol {
    var chainId: ChainModel.Id { get }
    var snapshot: RuntimeSnapshot? { get }
    var runtimeSpecVersion: RuntimeSpecVersion { get }

    func setup()
    func setupHot()
    func cleanup()
    func fetchCoderFactoryOperation(
        with timeout: TimeInterval,
        closure: RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol>
}

enum RuntimeProviderError: Error {
    case providerUnavailable
}

final class RuntimeProvider {
    struct PendingRequest {
        let resultClosure: (RuntimeCoderFactoryProtocol?) -> Void
        let queue: DispatchQueue?
    }

    internal let chainId: ChainModel.Id
    private let chainName: String
    private let chainModel: ChainModel
    private let usedRuntimePaths: [String: [String]]

    private let snapshotOperationFactory: RuntimeSnapshotFactoryProtocol
    private let snapshotHotOperationFactory: RuntimeHotBootSnapshotFactoryProtocol?
    private let eventCenter: EventCenterProtocol
    private let operationQueue: OperationQueue
    private let dataHasher: StorageHasher
    private let logger: LoggerProtocol?
    private let repository: AnyDataProviderRepository<RuntimeMetadataItem>

    private lazy var completionQueue: DispatchQueue = {
        DispatchQueue(
            label: "jp.co.soramitsu.fearless.fetchCoder.\(self.chainId)",
            qos: .userInitiated
        )
    }()

    private(set) var snapshot: RuntimeSnapshot?
    private(set) var pendingRequests: [PendingRequest] = []
    private(set) var currentWrapper: BaseOperation<RuntimeSnapshot?>?
    private var mutex = NSLock()

    private var chainTypes: Data?
    private var chainMetadata: RuntimeMetadataItem?

    init(
        chainModel: ChainModel,
        snapshotOperationFactory: RuntimeSnapshotFactoryProtocol,
        snapshotHotOperationFactory: RuntimeHotBootSnapshotFactoryProtocol?,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        dataHasher: StorageHasher = .twox256,
        logger: LoggerProtocol? = nil,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        usedRuntimePaths: [String: [String]],
        chainMetadata: RuntimeMetadataItem?,
        chainTypes: Data?
    ) {
        chainId = chainModel.chainId
        chainName = chainModel.name
        self.chainModel = chainModel
        self.snapshotOperationFactory = snapshotOperationFactory
        self.snapshotHotOperationFactory = snapshotHotOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.dataHasher = dataHasher
        self.logger = logger
        self.repository = repository
        self.usedRuntimePaths = usedRuntimePaths
        self.chainMetadata = chainMetadata
        self.chainTypes = chainTypes

        self.operationQueue.maxConcurrentOperationCount = 10

        eventCenter.add(observer: self, dispatchIn: DispatchQueue.global())
    }

    private func buildSnapshot() {
        guard
            let chainTypes = chainTypes,
            let chainMetadata = chainMetadata
        else {
            return
        }

        logger?.debug("Will start building snapshot for \(chainName)")

        let wrapper = snapshotOperationFactory.createRuntimeSnapshotWrapper(
            chainTypes: chainTypes,
            chainMetadata: chainMetadata,
            usedRuntimePaths: usedRuntimePaths
        )

        wrapper.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper.result)
            }
        }

        currentWrapper = wrapper

        operationQueue.addOperation(wrapper)
    }

    private func buildHotSnapshot() {
        logger?.debug("Will start building hot snapshot for \(chainName)")

        guard let snapshotHotOperationFactory = snapshotHotOperationFactory,
              let chainTypes = chainTypes
        else {
            return
        }

        let wrapper = snapshotHotOperationFactory.createRuntimeSnapshotWrapper(
            usedRuntimePaths: usedRuntimePaths,
            chainTypes: chainTypes
        )

        wrapper.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper.result)
            }
        }

        currentWrapper = wrapper

        operationQueue.addOperation(wrapper)
    }

    private func handleCompletion(result: Result<RuntimeSnapshot?, Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        switch result {
        case let .success(snapshot):
            currentWrapper = nil

            if let snapshot = snapshot {
                self.snapshot = snapshot

                logger?.debug("Did complete snapshot for: \(chainName), Will notify waiters: \(pendingRequests.count)")
                let event = RuntimeSnapshotReady(chainModel: chainModel)
                eventCenter.notify(with: event)

                resolveRequests()
            }
        case let .failure(error):
            currentWrapper = nil

            logger?.error("Failed to build snapshot for \(chainName): \(error)")
        case .none:
            break
        }
    }

    private func resolveRequests() {
        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach { deliver(snapshot: snapshot, to: $0) }
    }

    private func deliver(snapshot: RuntimeSnapshot?, to request: PendingRequest) {
        let coderFactory = snapshot.map {
            RuntimeCoderFactory(
                catalog: $0.typeRegistryCatalog,
                specVersion: $0.specVersion,
                txVersion: $0.txVersion,
                metadata: $0.metadata
            )
        }

        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(coderFactory)
        }
    }

    private func fetchCoderFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RuntimeCoderFactoryProtocol?) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
        }
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { [weak self] in
            guard let strongSelf = self else {
                throw RuntimeProviderError.providerUnavailable
            }

            var fetchedFactory: RuntimeCoderFactoryProtocol?

            let semaphore = DispatchSemaphore(value: 0)

            strongSelf.fetchCoderFactory(runCompletionIn: strongSelf.completionQueue) { factory in
                fetchedFactory = factory
                semaphore.signal()
            }

            semaphore.wait()

            guard let factory = fetchedFactory else {
                throw RuntimeProviderError.providerUnavailable
            }

            return factory
        }
    }

    func fetchCoderFactoryOperation(
        with _: TimeInterval,
        closure _: RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { [weak self] in
            guard let strongSelf = self else {
                throw RuntimeProviderError.providerUnavailable
            }

            var fetchedFactory: RuntimeCoderFactoryProtocol?
            let semaphore = DispatchSemaphore(value: 0)

            strongSelf.fetchCoderFactory(runCompletionIn: strongSelf.completionQueue) { factory in
                fetchedFactory = factory
                semaphore.signal()
            }

            semaphore.wait()

            guard let factory = fetchedFactory else {
                throw RuntimeProviderError.providerUnavailable
            }

            return factory
        }
    }
}

extension RuntimeProvider: RuntimeProviderProtocol {
    func setupHot() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard currentWrapper == nil else {
            return
        }

        buildHotSnapshot()
    }

    var runtimeSnapshot: RuntimeSnapshot? {
        snapshot
    }

    var runtimeSpecVersion: RuntimeSpecVersion {
        snapshot?.runtimeSpecVersion ?? RuntimeSpecVersion.defaultVersion
    }

    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard currentWrapper == nil else {
            return
        }

        buildSnapshot()
    }

    func cleanup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        snapshot = nil

        currentWrapper?.cancel()
        currentWrapper = nil

        resolveRequests()
    }
}

extension RuntimeProvider: EventVisitorProtocol {
    func processRuntimeChainsTypesSyncCompleted(event: RuntimeChainsTypesSyncCompleted) {
        guard let chainTypes = event.versioningMap[chainId] else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        self.chainTypes = chainTypes

        buildSnapshot()
    }

    func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted) {
        guard event.chainId == chainId else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        chainMetadata = event.metadata

        buildSnapshot()
    }
}
