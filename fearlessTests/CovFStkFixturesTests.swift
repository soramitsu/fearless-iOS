import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

enum CovFStkError: Error, Equatable {
    case stub(String)
}

/// An expectation that tolerates extra fulfilments from background callbacks.
func covFStkExpectation(_ description: String, count: Int = 1) -> XCTestExpectation {
    let expectation = XCTestExpectation(description: description)
    expectation.expectedFulfillmentCount = count
    expectation.assertForOverFulfill = false
    return expectation
}

/// JSON-RPC engine double: records storage subscriptions and unsubscriptions and lets a test push updates.
final class CovFStkEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private let lock = NSLock()
    private var nextIdentifier: UInt16 = 0
    private var recordedMethods: [String] = []
    private var recordedParams: [[String]] = []
    private var recordedUnsubscribed: [UInt16] = []
    private var recordedUnsubscribeAttempts: [UInt16] = []
    private var updateHandlers: [(Data) throws -> Void] = []
    private var failureHandlers: [(Error, Bool) -> Void] = []
    private var storedSubscribeError: Error?
    private var storedUnsubscribeError: Error?
    private var storedOnSubscribe: (() -> Void)?
    private var storedOnUnsubscribe: (() -> Void)?

    private func locked<T>(_ block: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try block()
    }

    var methods: [String] { locked { recordedMethods } }
    var params: [[String]] { locked { recordedParams } }
    var unsubscribed: [UInt16] { locked { recordedUnsubscribed } }
    var unsubscribeAttempts: [UInt16] { locked { recordedUnsubscribeAttempts } }

    var subscribeError: Error? {
        get { locked { storedSubscribeError } }
        set { locked { storedSubscribeError = newValue } }
    }

    var unsubscribeError: Error? {
        get { locked { storedUnsubscribeError } }
        set { locked { storedUnsubscribeError = newValue } }
    }

    var onSubscribe: (() -> Void)? {
        get { locked { storedOnSubscribe } }
        set { locked { storedOnSubscribe = newValue } }
    }

    var onUnsubscribe: (() -> Void)? {
        get { locked { storedOnUnsubscribe } }
        set { locked { storedOnUnsubscribe = newValue } }
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion _: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        throw CovFStkError.stub("unexpected call \(method)")
    }

    func subscribe<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        let registration: (UInt16, (() -> Void)?) = try locked {
            if let error = storedSubscribeError {
                throw error
            }
            recordedMethods.append(method)
            recordedParams.append((params as? [[String]])?.first ?? [])
            updateHandlers.append { data in updateClosure(try JSONDecoder().decode(T.self, from: data)) }
            failureHandlers.append(failureClosure)
            nextIdentifier += 1
            return (nextIdentifier, storedOnSubscribe)
        }
        registration.1?()
        return registration.0
    }

    func unsubsribe(_ identifier: UInt16) throws {
        let callback: (() -> Void)? = try locked {
            recordedUnsubscribeAttempts.append(identifier)
            if let error = storedUnsubscribeError {
                throw error
            }
            recordedUnsubscribed.append(identifier)
            return storedOnUnsubscribe
        }
        callback?()
    }

    /// Delivers a `state_storage` notification to the subscription opened at `index`.
    func deliver(_ index: Int = 0, block: String? = nil, changes: [[Any]]) throws {
        let handler: (Data) throws -> Void = try locked {
            guard updateHandlers.indices.contains(index) else {
                throw CovFStkError.stub("no subscription at \(index)")
            }
            return updateHandlers[index]
        }
        var result: [String: Any] = ["changes": changes]
        if let block = block {
            result["block"] = block
        }
        let message: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "state_storage",
            "params": ["subscription": "covfstk", "result": result]
        ]
        try handler(JSONSerialization.data(withJSONObject: message))
    }

    func fail(_ index: Int = 0, error: Error, unsubscribed: Bool) throws {
        let handler: (Error, Bool) -> Void = try locked {
            guard failureHandlers.indices.contains(index) else {
                throw CovFStkError.stub("no subscription at \(index)")
            }
            return failureHandlers[index]
        }
        handler(error, unsubscribed)
    }

    func generateRequestId() -> UInt16 {
        locked {
            nextIdentifier += 1
            return nextIdentifier
        }
    }

    func cancelForIdentifier(_: UInt16) {}
    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
}

final class CovFStkLogger: fearless.LoggerProtocol {
    private let lock = NSLock()
    private var storedErrors: [String] = []
    private var storedWarnings: [String] = []
    private var storedOnError: ((String) -> Void)?

    var errors: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedErrors
    }

    var warnings: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedWarnings
    }

    var onError: ((String) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedOnError
        }
        set {
            lock.lock()
            storedOnError = newValue
            lock.unlock()
        }
    }

    func hasError(prefix: String) -> Bool {
        errors.contains { $0.hasPrefix(prefix) }
    }

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}

    func warning(message: String, file _: String, function _: String, line _: Int) {
        lock.lock()
        storedWarnings.append(message)
        lock.unlock()
    }

    func error(message: String, file _: String, function _: String, line _: Int) {
        lock.lock()
        storedErrors.append(message)
        let callback = storedOnError
        lock.unlock()
        callback?(message)
    }

    func customError(error: Error, file _: String, function _: String, line _: Int) {
        lock.lock()
        storedErrors.append("\(error)")
        lock.unlock()
    }
}

final class CovFStkChild: StorageChildSubscribing {
    let remoteStorageKey: Data
    let localKey: String
    private let lock = NSLock()
    private var received: [(Data?, Data?)] = []

    init(keys: SubscriptionStorageKeys) {
        remoteStorageKey = keys.remote
        localKey = keys.local
    }

    var updates: [Data?] {
        lock.lock()
        defer { lock.unlock() }
        return received.map { $0.0 }
    }

    var blockHashes: [Data?] {
        lock.lock()
        defer { lock.unlock() }
        return received.map { $0.1 }
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        lock.lock()
        received.append((data, blockHash))
        lock.unlock()
    }
}

final class CovFStkChildFactory: ChildSubscriptionFactoryProtocol {
    private let lock = NSLock()
    private var storedChildren: [CovFStkChild] = []
    private var storedOnCreate: (() -> Void)?

    var children: [CovFStkChild] {
        lock.lock()
        defer { lock.unlock() }
        return storedChildren
    }

    var onCreate: (() -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedOnCreate
        }
        set {
            lock.lock()
            storedOnCreate = newValue
            lock.unlock()
        }
    }

    func createEmptyHandlingSubscription(keys: SubscriptionStorageKeys) -> StorageChildSubscribing {
        let child = CovFStkChild(keys: keys)
        lock.lock()
        storedChildren.append(child)
        let callback = storedOnCreate
        lock.unlock()
        callback?()
        return child
    }
}

enum CovFStkRuntimeMode {
    case factory(RuntimeCoderFactoryProtocol)
    case failure(Error)
    /// The coder operation finishes without any result.
    case empty
}

final class CovFStkRuntime: RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    let snapshot: RuntimeSnapshot? = nil
    let mode: CovFStkRuntimeMode

    init(_ mode: CovFStkRuntimeMode) {
        self.mode = mode
    }

    func setup() {}
    func setupHot() {}
    func cleanup() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        throw CovFStkError.stub("snapshot")
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        switch mode {
        case let .factory(factory):
            return factory
        case let .failure(error):
            throw error
        case .empty:
            throw CovFStkError.stub("empty")
        }
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        switch mode {
        case let .factory(factory):
            return ClosureOperation<RuntimeCoderFactoryProtocol> { factory }
        case let .failure(error):
            return ClosureOperation<RuntimeCoderFactoryProtocol> { throw error }
        case .empty:
            return BaseOperation<RuntimeCoderFactoryProtocol>()
        }
    }
}

/// Stash repository that records every save it applies.
final class CovFStkStashRepository: DataProviderRepositoryProtocol {
    typealias Model = StashItem

    private let lock = NSLock()
    private var storedItems: [StashItem]
    private var storedSaves: [([StashItem], [String])] = []
    private var storedFetchError: Error?

    init(_ items: [StashItem] = []) {
        storedItems = items
    }

    var items: [StashItem] {
        lock.lock()
        defer { lock.unlock() }
        return storedItems
    }

    var savedUpdates: [[StashItem]] {
        lock.lock()
        defer { lock.unlock() }
        return storedSaves.map { $0.0 }
    }

    var savedDeletes: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return storedSaves.map { $0.1 }
    }

    var fetchError: Error? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedFetchError
        }
        set {
            lock.lock()
            storedFetchError = newValue
            lock.unlock()
        }
    }

    private func apply(updates: [StashItem], deletes: [String]) {
        lock.lock()
        storedSaves.append((updates, deletes))
        let replaced = Set(updates.map(\.identifier))
        storedItems.removeAll { deletes.contains($0.identifier) || replaced.contains($0.identifier) }
        storedItems.append(contentsOf: updates)
        lock.unlock()
    }

    func fetchOperation(
        by modelIdsClosure: @escaping () throws -> [String],
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[StashItem]> {
        ClosureOperation<[StashItem]> {
            let identifiers = try modelIdsClosure()
            return self.items.filter { identifiers.contains($0.identifier) }
        }
    }

    func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<StashItem?> {
        ClosureOperation<StashItem?> {
            let identifier = try modelIdClosure()
            return self.items.first { $0.identifier == identifier }
        }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[StashItem]> {
        ClosureOperation<[StashItem]> {
            if let error = self.fetchError {
                throw error
            }
            return self.items
        }
    }

    func fetchOperation(by _: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[StashItem]> {
        fetchAllOperation(with: options)
    }

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [StashItem],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation<Void> {
            let updates = try updateModelsBlock()
            let deletes = try deleteIdsBlock()
            self.apply(updates: updates, deletes: deletes)
        }
    }

    func saveBatchOperation(
        _ updateModelsBlock: @escaping () throws -> [StashItem],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        saveOperation(updateModelsBlock, deleteIdsBlock)
    }

    func replaceOperation(_ newModelsBlock: @escaping () throws -> [StashItem]) -> BaseOperation<Void> {
        ClosureOperation<Void> {
            let current = self.items.map(\.identifier)
            self.apply(updates: try newModelsBlock(), deletes: current)
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation<Int> { self.items.count }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation<Void> {
            self.apply(updates: [], deletes: self.items.map(\.identifier))
        }
    }
}

/// Repository observable that lets a test push stash changes into a `StreamableProvider`.
final class CovFStkStashObservable: DataProviderRepositoryObservable {
    typealias Model = StashItem

    private let lock = NSLock()
    private var observers: [(DispatchQueue, ([DataProviderChange<StashItem>]) -> Void)] = []
    private var storedOnAdd: (() -> Void)?

    var onAdd: (() -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedOnAdd
        }
        set {
            lock.lock()
            storedOnAdd = newValue
            lock.unlock()
        }
    }

    func start(completionBlock: @escaping (Error?) -> Void) {
        completionBlock(nil)
    }

    func stop(completionBlock: @escaping (Error?) -> Void) {
        completionBlock(nil)
    }

    func addObserver(
        _: AnyObject,
        deliverOn queue: DispatchQueue,
        executing updateBlock: @escaping ([DataProviderChange<StashItem>]) -> Void
    ) {
        lock.lock()
        observers.append((queue, updateBlock))
        let callback = storedOnAdd
        lock.unlock()
        callback?()
    }

    func removeObserver(_: AnyObject) {}

    func emit(_ changes: [DataProviderChange<StashItem>]) {
        lock.lock()
        let current = observers
        lock.unlock()
        current.forEach { queue, block in
            queue.async { block(changes) }
        }
    }
}

enum CovFStkFixtures {
    static let accountId = Data(repeating: 0x11, count: 32)
    static let otherId = Data(repeating: 0x22, count: 32)
    static let thirdId = Data(repeating: 0x33, count: 32)
    static let blockHash = Data(repeating: 0xab, count: 32)
    static let format = ChainFormat.substrate(42)
    static let chainAsset = CovFFixtures.asset()

    private static let runtimeLock = NSLock()
    private static var cachedAssetHub: AssetHubRuntimeFixture?

    /// Asset Hub Polkadot metadata: it has the Staking, System and NominationPools storage the owners encode keys for.
    static func assetHub() throws -> AssetHubRuntimeFixture {
        runtimeLock.lock()
        defer { runtimeLock.unlock() }
        if let cachedAssetHub = cachedAssetHub {
            return cachedAssetHub
        }
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        cachedAssetHub = runtime
        return runtime
    }

    static func address(_ accountId: Data) throws -> String {
        try accountId.toAddress(using: format)
    }

    static func storagePrefix(_ path: fearless.StorageCodingPath) throws -> Data {
        try StorageKeyFactory().createStorageKey(moduleName: path.moduleName, storageName: path.itemName)
    }

    static func localKey(_ path: fearless.StorageCodingPath, accountId: Data) throws -> String {
        try LocalStorageKeyFactory().createFromStoragePath(path, chainAssetKey: chainAsset.uniqueKey(accountId: accountId))
    }

    static func ledger(stash: Data) throws -> StakingLedger {
        let json: [String: Any] = ["stash": stash.base64EncodedString(), "total": "40", "active": "20", "unlocking": [Any]()]
        return try JSONDecoder().decode(StakingLedger.self, from: JSONSerialization.data(withJSONObject: json))
    }

    static func update(block: Data? = nil, changes: [(Data, Data?)]) -> fearless.StorageUpdate {
        fearless.StorageUpdate(
            blockHash: block?.toHex(includePrefix: true),
            changes: changes.map { change -> [String?] in
                [change.0.toHex(includePrefix: true), change.1?.toHex(includePrefix: true)]
            }
        )
    }

    static func funds(index: UInt32) throws -> CrowdloanFunds {
        let json: [String: Any] = [
            "depositor": Data(repeating: 0x09, count: 32).base64EncodedString(),
            "deposit": "1",
            "raised": "2",
            "end": "3",
            "cap": "4",
            "lastContribution": ["Never"],
            "firstPeriod": "5",
            "lastPeriod": "6",
            "fundIndex": String(index)
        ]
        return try JSONDecoder().decode(CrowdloanFunds.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

/// Wires the staking subscription owners to recording doubles.
final class CovFStkHarness {
    let engine = CovFStkEngine()
    let logger = CovFStkLogger()
    let factory = CovFStkChildFactory()
    let registry = CovFRegistry()
    let queue = OperationQueue()
    let repository: CovFStkStashRepository
    let observable: CovFStkStashObservable
    let provider: StreamableProvider<StashItem>

    init(runtime: RuntimeProviderProtocol? = nil, connected: Bool = true, items: [StashItem] = []) {
        let repository = CovFStkStashRepository(items)
        let observable = CovFStkStashObservable()
        self.repository = repository
        self.observable = observable
        provider = StreamableProvider<StashItem>(
            source: AnyStreamableSource(fearless.EmptyStreamableSource<StashItem>()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager()
        )
        registry.runtime = runtime
        if connected {
            registry.connection = engine
        }
    }

    func makeV14Resolver() -> StakingAccountResolverV14 {
        StakingAccountResolverV14(
            accountId: CovFStkFixtures.accountId,
            chainAsset: CovFStkFixtures.chainAsset,
            chainFormat: CovFStkFixtures.format,
            chainRegistry: registry,
            childSubscriptionFactory: factory,
            operationQueue: queue,
            repository: AnyDataProviderRepository(repository),
            logger: logger
        )
    }

    func makeBaseSubscription() -> BaseStakingAccountSubscription {
        BaseStakingAccountSubscription(
            accountId: CovFStkFixtures.accountId,
            chainAsset: CovFStkFixtures.chainAsset,
            chainFormat: CovFStkFixtures.format,
            chainRegistry: registry,
            provider: provider,
            childSubscriptionFactory: factory,
            operationQueue: queue,
            logger: logger
        )
    }

    func makePool() -> PoolStakingAccountSubscription {
        PoolStakingAccountSubscription(
            accountId: CovFStkFixtures.accountId,
            chainAsset: CovFStkFixtures.chainAsset,
            chainFormat: CovFStkFixtures.format,
            chainRegistry: registry,
            childSubscriptionFactory: factory,
            operationQueue: queue,
            logger: logger
        )
    }
}
