import Foundation
import Starscream
@testable import SSFUtils
import XCTest

/// A Substrate node behind one WebSocket, answering the way SORA mainnet
/// (node 4.8.13) answered on 2026-11-07: every subscribe gets a fresh
/// subscription ID, an unsubscribe ends a subscription only when it names that
/// ID with the matching method (anything else answers `false` and the updates
/// continue), and each produced block notifies every live subscription.
final class SubstrateNodeDouble: Engine {
    struct Request {
        let id: Int
        let method: String
        let params: [Any]

        var stringParams: [String] { params.compactMap { $0 as? String } }
    }

    /// Subscribe method → its unsubscribe method and notification method.
    static let subscriptionMethods: [String: (unsubscribe: String, notification: String)] = [
        "state_subscribeStorage": ("state_unsubscribeStorage", "state_storage"),
        "chain_subscribeNewHeads": ("chain_unsubscribeNewHeads", "chain_newHead"),
        "chain_subscribeFinalizedHeads": ("chain_unsubscribeFinalizedHeads", "chain_finalizedHead"),
        "state_subscribeRuntimeVersion": ("state_unsubscribeRuntimeVersion", "state_runtimeVersion")
    ]

    private let lock = NSLock()
    private weak var delegate: EngineDelegate?
    private var received: [Request] = []
    private var live: [String: String] = [:]
    private var held: [String] = []
    private var subscriptionCount = 0
    private var blockNumber = 0
    private var starts = 0
    private var accepting = true
    private var holdingSubscribeAnswers = false
    private var holdingUnsubscribeAnswers = false

    var acceptsConnections: Bool {
        get { locked { accepting } }
        set { locked { accepting = newValue } }
    }

    /// Keeps subscribe answers (the subscription IDs) until `releaseHeldAnswers()`.
    var holdsSubscribeAnswers: Bool {
        get { locked { holdingSubscribeAnswers } }
        set { locked { holdingSubscribeAnswers = newValue } }
    }

    var holdsUnsubscribeAnswers: Bool {
        get { locked { holdingUnsubscribeAnswers } }
        set { locked { holdingUnsubscribeAnswers = newValue } }
    }

    var requests: [Request] { locked { received } }
    var liveSubscriptions: [String] { locked { live.keys.sorted() } }
    var connectionAttempts: Int { locked { starts } }

    func requests(_ method: String) -> [Request] {
        requests.filter { $0.method == method }
    }

    func produceBlock() {
        let notifications: [String] = locked {
            blockNumber += 1
            return live.sorted { $0.key < $1.key }.compactMap { subscriptionId, method in
                Self.subscriptionMethods[method].map {
                    Self.notification(method: $0.notification, subscription: subscriptionId, block: blockNumber)
                }
            }
        }
        notifications.forEach { emit(.text($0)) }
    }

    /// Sends one notification, whether or not the node still has that subscription.
    func notify(subscription: String, method: String = "state_storage") {
        let block = locked { () -> Int in
            blockNumber += 1
            return blockNumber
        }
        emit(.text(Self.notification(method: method, subscription: subscription, block: block)))
    }

    func releaseHeldAnswers() {
        let answers: [String] = locked {
            defer { held.removeAll() }
            return held
        }
        answers.forEach { emit(.text($0)) }
    }

    /// The socket closes, and with it every subscription it carried.
    func dropConnection() {
        locked {
            live.removeAll()
            held.removeAll()
        }
        emit(.disconnected("Connection dropped", 1006))
    }

    func emit(_ event: WebSocketEvent) {
        let target = locked { delegate }
        target?.didReceive(event: event)
    }

    // MARK: Engine

    func register(delegate: EngineDelegate) {
        locked { self.delegate = delegate }
    }

    func start(request _: URLRequest) {
        let accepts: Bool = locked {
            starts += 1
            return accepting
        }
        if accepts {
            emit(.connected([:]))
        }
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
        let answers: [String] = locked {
            received.append(Request(id: id, method: method, params: params))

            if Self.subscriptionMethods[method] != nil {
                subscriptionCount += 1
                let subscriptionId = "sub-\(subscriptionCount)"
                live[subscriptionId] = method
                return answer(Self.response(id: id, result: subscriptionId), hold: holdingSubscribeAnswers)
            }

            if let subscribeMethod = Self.subscriptionMethods.first(where: { $0.value.unsubscribe == method })?.key {
                var ended = false
                if params.count == 1,
                   let subscriptionId = params[0] as? String,
                   live[subscriptionId] == subscribeMethod {
                    live[subscriptionId] = nil
                    ended = true
                }
                return answer(Self.response(id: id, result: ended), hold: holdingUnsubscribeAnswers)
            }

            return [Self.response(id: id, result: NSNull())]
        }
        answers.forEach { emit(.text($0)) }
    }

    // MARK: Private

    private func answer(_ response: String, hold: Bool) -> [String] {
        guard hold else {
            return [response]
        }
        held.append(response)
        return []
    }

    private func locked<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }

    private static func response(id: Int, result: Any) -> String {
        encode(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private static func notification(method: String, subscription: String, block: Int) -> String {
        encode([
            "jsonrpc": "2.0",
            "method": method,
            "params": ["subscription": subscription, "result": ["block": block]]
        ])
    }

    private static func encode(_ object: [String: Any]) -> String {
        let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}

/// The payload every notification from `SubstrateNodeDouble` carries.
struct BlockNotification: Decodable {
    let block: Int
}

final class UpdateCounter {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func record(_: JSONRPCSubscriptionUpdate<BlockNotification>) {
        lock.lock()
        value += 1
        lock.unlock()
    }
}

/// A real `WebSocketEngine` whose socket talks to a `SubstrateNodeDouble`.
final class NodeConnectedEngine {
    // twox128("System") ++ twox128("Number"): the key Polkaswap watches for blocks.
    static let blockNumberKey = "0x26aa394eea5630e07c48ae0c9558cef702a5c1b19ab7a04f536c519aca4983ac"

    let queue = DispatchQueue(label: "test.ssfutils.websocket-engine")
    let node = SubstrateNodeDouble()
    let engine: WebSocketEngine

    init(connected: Bool = true) {
        let url = URL(string: "wss://node.invalid")!
        engine = WebSocketEngine(
            connectionName: "unsubscribe-fixture",
            url: url,
            reachabilityManager: AlwaysReachable(),
            reconnectionStrategy: ImmediateReconnection(),
            processingQueue: queue,
            autoconnect: false,
            pingInterval: 0
        )
        let socket = WebSocket(request: URLRequest(url: url), engine: node)
        socket.callbackQueue = queue
        socket.delegate = engine
        engine.connection = socket

        if connected {
            engine.connectIfNeeded()
            waitUntil("engine connects") { self.isConnected }
        }
    }

    var isConnected: Bool {
        locked {
            if case .connected = engine.state {
                return true
            }
            return false
        }
    }

    var pendingRequestIds: [UInt16] { locked { engine.pendingRequests.map(\.requestId) } }
    var unknownUpdates: [String: [Data]] { locked { engine.unknownResponsesByRemoteId } }

    func hasSubscription(_ identifier: UInt16) -> Bool {
        locked { engine.subscriptions[identifier] != nil }
    }

    func remoteId(of identifier: UInt16) -> String? {
        locked { engine.subscriptions[identifier]?.remoteId }
    }

    func subscribeToBlockNumber(_ updates: UpdateCounter) throws -> UInt16 {
        try engine.subscribe(
            RPCMethod.storageSubscribe,
            params: [[Self.blockNumberKey]],
            updateClosure: updates.record,
            failureClosure: { _, _ in }
        )
    }

    /// Runs every socket event and completion already queued, and those they queue.
    func settle() {
        for _ in 0 ..< 8 {
            queue.sync {}
        }
    }

    private func locked<T>(_ work: () -> T) -> T {
        engine.mutex.lock()
        defer { engine.mutex.unlock() }
        return work()
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

private final class AlwaysReachable: ReachabilityManagerProtocol {
    let isReachable = true
    func add(listener _: ReachabilityListenerDelegate) throws {}
    func remove(listener _: ReachabilityListenerDelegate) {}
}

private struct ImmediateReconnection: ReconnectionStrategyProtocol {
    func reconnectAfter(attempt _: Int) -> TimeInterval? { 0.01 }
}
