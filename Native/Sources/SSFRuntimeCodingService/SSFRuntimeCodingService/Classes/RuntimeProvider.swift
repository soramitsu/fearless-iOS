import Foundation
import RobinHood
import SSFModels
import SSFUtils

public enum RuntimeSpecVersion: UInt32 {
    case v9370 = 9370
    case v9380 = 9380
    case v9390 = 9390
    case v9420 = 9420

    public static let defaultVersion: RuntimeSpecVersion = .v9390

    public init?(rawValue: UInt32) {
        switch rawValue {
        case 9370:
            self = .v9370
        case 9380:
            self = .v9380
        case 9390:
            self = .v9390
        case 9420:
            self = .v9420
        default:
            self = RuntimeSpecVersion.defaultVersion
        }
    }

    // Helper methods

    public func higherOrEqualThan(_ version: RuntimeSpecVersion) -> Bool {
        rawValue >= version.rawValue
    }

    public func lowerOrEqualThan(_ version: RuntimeSpecVersion) -> Bool {
        rawValue <= version.rawValue
    }
}

public protocol RuntimeProviderProtocol: AnyObject, RuntimeCodingServiceProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion { get }

    func setup()
    func readySnapshot() async throws -> RuntimeSnapshot
    func cleanup()
    func setupHot()
}

public enum RuntimeProviderError: Error {
    case providerUnavailable
    case buildSnapshotError
    case fetchCoderFactoryTimeout
}

public final class RuntimeProvider {
    struct PendingRequest {
        let resultClosure: (RuntimeCoderFactoryProtocol?) -> Void
        let queue: DispatchQueue?
    }

    private let usedRuntimePaths: [String: [String]]
    private var chainMetadata: RuntimeMetadataItemProtocol
    private let operationQueue: OperationQueue
    private var chainTypes: Data

    private lazy var snapshotOperationFactory: RuntimeSnapshotFactoryProtocol =
        RuntimeSnapshotFactory()

    private lazy var completionQueue: DispatchQueue = .init(
        label: "jp.co.soramitsu.fearless.fetchCoder.\(UUID().uuidString)",
        qos: .userInitiated
    )

    public var snapshot: RuntimeSnapshot?
    private(set) var pendingRequests: [PendingRequest] = []
    private(set) var currentWrapper: BaseOperation<RuntimeSnapshot?>?
    private var mutex = NSLock()

    public init(
        operationQueue: OperationQueue,
        usedRuntimePaths: [String: [String]],
        chainMetadata: RuntimeMetadataItemProtocol,
        chainTypes: Data
    ) {
        self.operationQueue = operationQueue
        self.usedRuntimePaths = usedRuntimePaths
        self.chainMetadata = chainMetadata
        self.chainTypes = chainTypes
    }

    private func buildSnapshot() {
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
                resolveRequests()
            }
        case .failure:
            currentWrapper = nil
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

        completionQueue.async {
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
}

extension RuntimeProvider: RuntimeProviderProtocol {
    public var runtimeSpecVersion: RuntimeSpecVersion {
        runtimeSnapshot?.runtimeSpecVersion ?? RuntimeSpecVersion.defaultVersion
    }

    var runtimeSnapshot: RuntimeSnapshot? {
        snapshot
    }

    public func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard currentWrapper == nil else {
            return
        }

        buildSnapshot()
    }

    public func readySnapshot() async throws -> RuntimeSnapshot {
        let wrapper = snapshotOperationFactory.createRuntimeSnapshotWrapper(
            chainTypes: chainTypes,
            chainMetadata: chainMetadata,
            usedRuntimePaths: usedRuntimePaths
        )
        currentWrapper = wrapper
        operationQueue.addOperation(wrapper)

        return try await withUnsafeThrowingContinuation { continuation in
            wrapper.completionBlock = { [weak self] in
                let result = wrapper.result
                self?.handleCompletion(result: result)
                switch result {
                case let .success(snapshot):
                    guard let snapshot = snapshot else {
                        return continuation
                            .resume(throwing: RuntimeProviderError.buildSnapshotError)
                    }
                    return continuation.resume(returning: snapshot)
                case let .failure(error):
                    return continuation.resume(throwing: error)
                case .none:
                    return continuation.resume(throwing: RuntimeProviderError.buildSnapshotError)
                }
            }
        }
    }

    public func cleanup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        snapshot = nil

        currentWrapper?.cancel()
        currentWrapper = nil

        resolveRequests()
    }

    public func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        AwaitOperation { [weak self] in
            try await withCheckedThrowingContinuation { continuation in
                guard let self = self else {
                    continuation.resume(throwing: RuntimeProviderError.providerUnavailable)
                    return
                }

                let timeoutTask = Task {
                    let duration = UInt64(20 * 1_000_000_000)
                    try await Task.sleep(nanoseconds: duration)
                    continuation.resume(throwing: RuntimeProviderError.fetchCoderFactoryTimeout)
                }

                self.fetchCoderFactory(runCompletionIn: nil) { factory in
                    timeoutTask.cancel()
                    guard let factory = factory else {
                        continuation
                            .resume(with: .failure(RuntimeProviderError.providerUnavailable))
                        return
                    }

                    continuation.resume(with: .success(factory))
                }
            }
        }
    }

    public func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        try await withUnsafeThrowingContinuation { continuation in
            fetchCoderFactory(runCompletionIn: nil) { factory in
                guard let factory = factory else {
                    continuation.resume(with: .failure(RuntimeProviderError.providerUnavailable))
                    return
                }

                continuation.resume(with: .success(factory))
            }
        }
    }
    
    public func setupHot() {}
}
