import IrohaCrypto
import SSFUtils
import XCTest
@testable import fearless

/// The dispatch watcher's fail-safe paths: a block without the extrinsic, a node that cannot be asked, missing events,
/// and a best-block inclusion whose unwatch request fails.
final class CovHCCConfirmWatcherTests: XCTestCase {
    private let extrinsic = "0x0502"

    private func hash() throws -> String {
        try Data(hexStringSSF: extrinsic).blake2b32().toHex(includePrefix: true)
    }

    private func outcome(_ engine: CovHCCConfirmWatchEngine) throws -> ReviewedCrossChainDispatchOutcome? {
        let watcher = ReviewedCrossChainDispatchWatcher(
            connection: engine,
            runtime: CovHCCConfirmRuntime(factory: try CovHCCConfirmFixture.coderFactory()),
            timeout: 2
        )
        let hash = try hash()
        return CovHCCConfirmAsyncBox { await watcher.outcome(subscriptionId: "subscription", extrinsicHash: hash) }.value
    }

    func testAFinalizedBlockWithoutTheExtrinsicStaysInDoubt() throws {
        let engine = CovHCCConfirmWatchEngine(statuses: [#"{"finalized":"0xblock"}"#], extrinsics: ["0x0401"])
        XCTAssertEqual(try outcome(engine), .unknown)
        XCTAssertEqual(engine.methods, [RPCMethod.getChainBlock])
        XCTAssertEqual(engine.unsubscribes, 1, "The node ended a finalized subscription; only the local watcher is removed")
    }

    func testABestBlockWhoseEventsCannotBeReadStaysInDoubtAndStopsWatching() throws {
        let engine = CovHCCConfirmWatchEngine(statuses: [#"{"inBlock":"0xbest"}"#], extrinsics: ["0x0401", extrinsic], endsSubscription: true)
        engine.failingMethods = [RPCMethod.unwatchExtrinsic]
        XCTAssertEqual(try outcome(engine), .unknown)
        XCTAssertEqual(engine.methods, [RPCMethod.unwatchExtrinsic, RPCMethod.getChainBlock, RPCMethod.getStorage])
        XCTAssertEqual(engine.unsubscribes, 1, "A failed unwatch request still removes the watcher")
    }

    func testANodeThatCannotBeAskedForTheBlockStaysInDoubt() throws {
        let engine = CovHCCConfirmWatchEngine(statuses: [#"{"finalized":"0xblock"}"#], extrinsics: [extrinsic])
        engine.failingMethods = [RPCMethod.getChainBlock]
        XCTAssertEqual(try outcome(engine), .unknown)
        XCTAssertEqual(engine.methods, [RPCMethod.getChainBlock])
    }
}

/// Reports scripted statuses for the watched extrinsic and answers the block and its events.
final class CovHCCConfirmWatchEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    var failingMethods: Set<String> = []

    private let statuses: [String]
    private let extrinsics: [String]
    private let endsSubscription: Bool
    private let lock = NSLock()
    private var recordedMethods: [String] = []
    private var recordedUnsubscribes = 0

    var methods: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedMethods
    }

    var unsubscribes: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedUnsubscribes
    }

    init(statuses: [String], extrinsics: [String], endsSubscription: Bool = false) {
        self.statuses = statuses
        self.extrinsics = extrinsics
        self.endsSubscription = endsSubscription
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        lock.lock()
        recordedMethods.append(method)
        lock.unlock()
        if failingMethods.contains(method) {
            throw CovHCCConfirmError.stub
        }
        let answer: Any
        switch method {
        case RPCMethod.getChainBlock:
            let header: [String: Any] = [
                "digest": ["logs": [String]()],
                "extrinsicsRoot": "0x00",
                "number": "0x0",
                "stateRoot": "0x00",
                "parentHash": "0x00"
            ]
            answer = ["block": ["header": header, "extrinsics": extrinsics], "justification": NSNull()]
        case RPCMethod.getStorage:
            answer = NSNull()
        default:
            closure?(.failure(JSONRPCEngineError.unknownError))
            return 0
        }
        let data = try JSONSerialization.data(withJSONObject: [answer])
        closure?(Result { try JSONDecoder().decode([T].self, from: data)[0] })
        return 0
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        0
    }

    func addSubscription(_ subscription: JSONRPCSubscribing) {
        let statuses = statuses
        let endsSubscription = endsSubscription
        DispatchQueue.global().async {
            for status in statuses {
                let update = #"{"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"subscription","result":\#(status)}}"#
                try? subscription.handle(data: Data(update.utf8))
            }
            if endsSubscription {
                subscription.handle(error: JSONRPCEngineError.remoteCancelled, unsubscribed: true)
            }
        }
    }

    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 7 }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}

    func unsubsribe(_: UInt16) throws {
        lock.lock()
        recordedUnsubscribes += 1
        lock.unlock()
    }
}
