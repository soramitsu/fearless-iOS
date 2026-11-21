import Foundation
import Starscream
@testable import SSFUtils
import XCTest
@testable import fearless

/// A SORA node behind one WebSocket, answering the way mainnet (node 4.8.13)
/// answered on 2026-11-07: each subscribe method gets a fresh subscription ID,
/// and a subscription ends only when its ID is sent with the unsubscribe method
/// that matches its subscribe method (anything else answers `false` and the
/// updates continue). Each block notifies every live storage subscription.
final class ScriptedSubstrateNode: Engine {
    struct Request {
        let method: String
        let params: [Any]

        var stringParams: [String] { params.compactMap { $0 as? String } }
    }

    /// A subscription method, the only method that ends it, and its notifications.
    private struct Kind: Equatable {
        let subscribe: String
        let unsubscribe: String
        let notification: String

        static let storage = Kind(
            subscribe: "state_subscribeStorage",
            unsubscribe: "state_unsubscribeStorage",
            notification: "state_storage"
        )
        static let runtimeVersion = Kind(
            subscribe: "state_subscribeRuntimeVersion",
            unsubscribe: "state_unsubscribeRuntimeVersion",
            notification: "state_runtimeVersion"
        )
        static let extrinsicStatus = Kind(
            subscribe: "author_submitAndWatchExtrinsic",
            unsubscribe: "author_unwatchExtrinsic",
            notification: "author_extrinsicUpdate"
        )
        static let all = [storage, runtimeVersion, extrinsicStatus]
    }

    private struct Subscription {
        let kind: Kind
        let storageKeys: [String]
    }

    private let lock = NSLock()
    private weak var delegate: EngineDelegate?
    private var received: [Request] = []
    private var live: [String: Subscription] = [:]
    private var subscriptionCount = 0
    private var blockNumber = 0

    var requests: [Request] { locked { received } }
    var liveSubscriptions: [String] { locked { live.keys.sorted() } }

    func requests(_ method: String) -> [Request] {
        requests.filter { $0.method == method }
    }

    func produceBlock() {
        let notifications: [String] = locked {
            blockNumber += 1
            let block = String(format: "0x%064x", blockNumber)
            let value = String(format: "0x%08x", blockNumber)
            return live.filter { $0.value.kind == .storage }.sorted { $0.key < $1.key }.map { subscriptionId, subscription in
                Self.notification(
                    .storage,
                    subscriptionId: subscriptionId,
                    result: ["block": block, "changes": subscription.storageKeys.map { [$0, value] }]
                )
            }
        }
        notifications.forEach { emit(.text($0)) }
    }

    /// Notifies every runtime version subscription of a runtime upgrade.
    func upgradeRuntime(specVersion: UInt32, transactionVersion: UInt32 = 1) {
        let notifications: [String] = locked {
            live.filter { $0.value.kind == .runtimeVersion }.keys.sorted().map {
                Self.notification(
                    .runtimeVersion,
                    subscriptionId: $0,
                    result: ["specVersion": specVersion, "transactionVersion": transactionVersion]
                )
            }
        }
        notifications.forEach { emit(.text($0)) }
    }

    /// Reports an extrinsic status, such as `["inBlock": "0x…"]`, to every
    /// extrinsic watch. After a final status such as `finalized` the node ends
    /// the watch itself.
    func reportExtrinsicStatus(_ status: Any, isFinal: Bool = false) {
        let notifications: [String] = locked {
            let watches = live.filter { $0.value.kind == .extrinsicStatus }.keys.sorted()
            if isFinal {
                watches.forEach { live[$0] = nil }
            }
            return watches.map { Self.notification(.extrinsicStatus, subscriptionId: $0, result: status) }
        }
        notifications.forEach { emit(.text($0)) }
    }

    // MARK: Engine

    func register(delegate: EngineDelegate) {
        locked { self.delegate = delegate }
    }

    func start(request _: URLRequest) {
        emit(.connected([:]))
    }

    func stop(closeCode _: UInt16) {}

    func forceStop() {}

    func write(string: String, completion: (() -> Void)?) {
        write(data: Data(string.utf8), opcode: .textFrame, completion: completion)
    }

    func write(data: Data, opcode: FrameOpCode, completion: (() -> Void)?) {
        defer { completion?() }

        guard opcode == .textFrame,
              let frame = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = frame["id"] as? Int,
              let method = frame["method"] as? String
        else {
            return
        }

        let params = frame["params"] as? [Any] ?? []
        let result: Any = locked {
            received.append(Request(method: method, params: params))

            if let kind = Kind.all.first(where: { $0.subscribe == method }) {
                subscriptionCount += 1
                let subscriptionId = "sub-\(subscriptionCount)"
                let storageKeys = kind == .storage ? (params.first as? [String] ?? []) : []
                live[subscriptionId] = Subscription(kind: kind, storageKeys: storageKeys)
                return subscriptionId
            }

            if Kind.all.contains(where: { $0.unsubscribe == method }) {
                guard params.count == 1, let subscriptionId = params[0] as? String,
                      live[subscriptionId]?.kind.unsubscribe == method
                else {
                    return false
                }
                live[subscriptionId] = nil
                return true
            }

            return NSNull()
        }
        emit(.text(Self.encode(["jsonrpc": "2.0", "id": id, "result": result])))
    }

    // MARK: Private

    private func emit(_ event: WebSocketEvent) {
        let target = locked { delegate }
        target?.didReceive(event: event)
    }

    private func locked<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }

    private static func notification(_ kind: Kind, subscriptionId: String, result: Any) -> String {
        encode([
            "jsonrpc": "2.0",
            "method": kind.notification,
            "params": ["subscription": subscriptionId, "result": result]
        ])
    }

    private static func encode(_ object: [String: Any]) -> String {
        let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}

/// A real `WebSocketEngine` whose socket talks to a `ScriptedSubstrateNode`.
final class ScriptedSubstrateConnection {
    let queue = DispatchQueue(label: "test.fearless.scripted-substrate")
    let node = ScriptedSubstrateNode()
    let engine: WebSocketEngine
    private let stateObserver = ScriptedStateObserver()
    private static let url = URL(string: "wss://sora.invalid")!

    init() {
        let url = Self.url
        engine = WebSocketEngine(
            connectionName: "scripted-sora",
            url: url,
            reachabilityManager: ScriptedReachability(),
            processingQueue: queue,
            autoconnect: false,
            pingInterval: 0
        )
        let socket = WebSocket(request: URLRequest(url: url), engine: node)
        socket.callbackQueue = queue
        socket.delegate = engine
        engine.connection = socket
        engine.connectIfNeeded()
        waitUntil("the engine connects") { self.isConnected }
    }

    var isConnected: Bool {
        locked {
            if case .connected = engine.state {
                return true
            }
            return false
        }
    }

    /// Remote IDs of the subscriptions the engine still delivers updates for.
    var deliveredRemoteIds: [String] {
        locked { engine.subscriptions.values.compactMap(\.remoteId).sorted() }
    }

    var registeredSubscriptionCount: Int { locked { engine.subscriptions.count } }

    /// The engine behind a `FailoverChainConnection`, as `ChainRegistry.getConnection(for:)` hands it out.
    func makeChainConnection() throws -> ChainConnection {
        try FailoverChainConnection(
            connectionName: "scripted-sora",
            urls: [Self.url],
            delegate: stateObserver,
            processingQueue: queue,
            logger: Logger.shared,
            engineFactory: { [engine] _, _ in engine }
        )
    }

    /// Submits an extrinsic the way `ExtrinsicOperationFactory.submitAndWatch` does: a
    /// plain call whose answer is the ID of the node's status subscription.
    func submitAndWatch(
        _ extrinsic: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let answered = DispatchSemaphore(value: 0)
        var answer: Result<String, Error>?
        _ = try engine.callMethod(
            "author_submitAndWatchExtrinsic",
            params: [extrinsic],
            options: JSONRPCOptions(resendOnReconnect: false)
        ) { (result: Result<String, Error>) in
            answer = result
            answered.signal()
        }
        _ = answered.wait(timeout: .now() + 3)
        return try XCTUnwrap(answer, "the node answers the submission", file: file, line: line).get()
    }

    /// Runs every socket event and completion already queued, and those they queue.
    func settle() {
        for _ in 0 ..< 8 {
            queue.sync {}
        }
    }

    func waitUntil(
        _ description: String,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out waiting until \(description)", file: file, line: line)
                return
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
    }

    private func locked<T>(_ work: () -> T) -> T {
        engine.mutex.lock()
        defer { engine.mutex.unlock() }
        return work()
    }
}

private final class ScriptedStateObserver: WebSocketEngineDelegate {
    func webSocketDidChangeState(
        engine _: WebSocketEngine,
        from _: WebSocketEngine.State,
        to _: WebSocketEngine.State
    ) {}
}

private final class ScriptedReachability: ReachabilityManagerProtocol {
    let isReachable = true
    func add(listener _: ReachabilityListenerDelegate) throws {}
    func remove(listener _: ReachabilityListenerDelegate) {}
}
