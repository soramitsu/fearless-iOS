import Foundation
import Starscream
@testable import SSFUtils
import XCTest

/// A SORA node behind one WebSocket, answering the way mainnet (node 4.8.13)
/// answered on 2026-11-07: `state_subscribeStorage` gets a fresh subscription
/// ID, `state_unsubscribeStorage` ends a subscription only when given that ID
/// (anything else answers `false` and the updates continue), and each block
/// notifies every live subscription.
final class ScriptedSubstrateNode: Engine {
    struct Request {
        let method: String
        let params: [Any]

        var stringParams: [String] { params.compactMap { $0 as? String } }
    }

    private let lock = NSLock()
    private weak var delegate: EngineDelegate?
    private var received: [Request] = []
    private var live: [String: [String]] = [:]
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
            return live.sorted { $0.key < $1.key }.map { subscriptionId, keys in
                Self.encode([
                    "jsonrpc": "2.0",
                    "method": "state_storage",
                    "params": [
                        "subscription": subscriptionId,
                        "result": ["block": block, "changes": keys.map { [$0, value] }]
                    ]
                ])
            }
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

            switch method {
            case "state_subscribeStorage":
                subscriptionCount += 1
                let subscriptionId = "sub-\(subscriptionCount)"
                live[subscriptionId] = params.first as? [String] ?? []
                return subscriptionId
            case "state_unsubscribeStorage":
                guard params.count == 1, let subscriptionId = params[0] as? String, live[subscriptionId] != nil else {
                    return false
                }
                live[subscriptionId] = nil
                return true
            default:
                return NSNull()
            }
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

    init() {
        let url = URL(string: "wss://sora.invalid")!
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

private final class ScriptedReachability: ReachabilityManagerProtocol {
    let isReachable = true
    func add(listener _: ReachabilityListenerDelegate) throws {}
    func remove(listener _: ReachabilityListenerDelegate) {}
}
