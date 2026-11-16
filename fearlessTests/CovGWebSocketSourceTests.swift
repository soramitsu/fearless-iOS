import Foundation
import RobinHood
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovGWebSocketSourceTests: XCTestCase {
    func testSubscribedValueIsDecodedForItemAndPageFetchesAndUnknownIdsStayEmpty() throws {
        let key = try StorageKeyFactory().key(from: .currentEra)
        let engine = CovGSubscriptionEngine()
        let observer = CovGTriggerCounter()
        let trigger = DataProviderProxyTrigger()
        trigger.delegate = observer
        var source: WebSocketProviderSource<fearless.StringScaleMapper<UInt32>>? = WebSocketProviderSource(
            itemIdentifier: "era", codingPath: .currentEra, keyOperationClosure: { _ in ClosureOperation { [key] } },
            runtimeService: CovGHistoryRuntime(), engine: engine, trigger: trigger, operationManager: OperationManager()
        )
        let live = try XCTUnwrap(source)
        waitUntil { engine.isSubscribed }
        XCTAssertEqual(engine.method, RPCMethod.storageSubscribe)
        XCTAssertEqual(engine.parameters, "[[\"\(key.toHex(includePrefix: true))\"]]")
        XCTAssertNil(try CovGOperationFixtures.run(live.fetchOperation(by: "era"))?.item)
        let other = try CovGOperationFixtures.run(live.fetchOperation(by: "other"))
        XCTAssertEqual(other?.identifier, "other")
        XCTAssertNil(other?.item)

        try engine.send(update(key: key, value: "0x2a000000"))
        XCTAssertEqual(observer.count, 1)
        XCTAssertEqual(try CovGOperationFixtures.run(live.fetchOperation(by: "era"))?.item?.value, 42)
        let page = try CovGOperationFixtures.run(live.fetchOperation(page: 0))
        XCTAssertEqual(page.map(\.identifier), ["era"])
        XCTAssertEqual(page.first?.item?.value, 42)

        try engine.send(update(key: key, value: "0x2a000000"))
        try engine.send(update(key: Data(repeating: 9, count: 32), value: "0x01000000"))
        XCTAssertEqual(observer.count, 1)

        try engine.send(update(key: key, value: nil))
        XCTAssertEqual(observer.count, 2)
        XCTAssertNil(try CovGOperationFixtures.run(live.fetchOperation(page: 0)).first?.item)

        engine.failSubscription(NSError(domain: "CovG.socket", code: 61))
        XCTAssertEqual(observer.count, 3)
        XCTAssertThrowsError(try CovGOperationFixtures.run(live.fetchOperation(by: "era"))) { XCTAssertEqual(($0 as NSError).code, 61) }
        XCTAssertThrowsError(try CovGOperationFixtures.run(live.fetchOperation(page: 0))) { XCTAssertEqual(($0 as NSError).code, 61) }

        try engine.send(update(key: key, value: "0x07000000"))
        XCTAssertEqual(observer.count, 4)
        XCTAssertEqual(try CovGOperationFixtures.run(live.fetchOperation(by: "era"))?.item?.value, 7)

        source = nil
        withExtendedLifetime(live) {}
        XCTAssertNil(source)
    }

    func testReleasingSourceEndsItsSubscription() throws {
        let key = try StorageKeyFactory().key(from: .currentEra)
        let engine = CovGSubscriptionEngine()
        let trigger = DataProviderProxyTrigger()
        var source: WebSocketProviderSource<fearless.StringScaleMapper<UInt32>>? = WebSocketProviderSource(
            itemIdentifier: "era", codingPath: .currentEra, keyOperationClosure: { _ in ClosureOperation { [key] } },
            runtimeService: CovGHistoryRuntime(), engine: engine, trigger: trigger, operationManager: OperationManager()
        )
        waitUntil { engine.isSubscribed }
        XCTAssertNotNil(source)
        source = nil
        XCTAssertEqual(engine.unsubscribed, [CovGSubscriptionEngine.subscriptionId])
    }

    func testKeyAndSubscriptionFailuresAreReportedThroughFetch() throws {
        let cases: [(WebSocketProviderKeyClosure, Error?, (Error) -> Bool)] = [
            ({ _ in throw NSError(domain: "CovG.key", code: 62) }, nil, { ($0 as NSError).code == 62 }),
            ({ _ in ClosureOperation { [Data]() } }, nil, { ($0 as? WebSocketProviderSourceError) == .noKeysFound }),
            ({ _ in ClosureOperation { throw NSError(domain: "CovG.keyOperation", code: 63) } }, nil, { ($0 as NSError).code == 63 }),
        ]
        for (closure, subscribeError, matches) in cases {
            let engine = CovGSubscriptionEngine()
            engine.subscribeError = subscribeError
            let observer = CovGTriggerCounter()
            let trigger = DataProviderProxyTrigger()
            trigger.delegate = observer
            let source = WebSocketProviderSource<fearless.StringScaleMapper<UInt32>>(
                itemIdentifier: "era", codingPath: .currentEra, keyOperationClosure: closure,
                runtimeService: CovGHistoryRuntime(), engine: engine, trigger: trigger, operationManager: OperationManager()
            )
            waitUntil { observer.count == 1 }
            XCTAssertFalse(engine.isSubscribed)
            XCTAssertThrowsError(try CovGOperationFixtures.run(source.fetchOperation(by: "era"))) { XCTAssertTrue(matches($0), "\($0)") }
            XCTAssertThrowsError(try CovGOperationFixtures.run(source.fetchOperation(page: 0))) { XCTAssertTrue(matches($0), "\($0)") }
            XCTAssertEqual(try CovGOperationFixtures.run(source.fetchOperation(by: "unrelated"))?.identifier, "unrelated")
        }
    }

    func testRuntimeFailureDuringDecodingIsForwarded() throws {
        let key = try StorageKeyFactory().key(from: .currentEra)
        let engine = CovGSubscriptionEngine()
        let runtime = CovGFailingRuntimeService()
        let source = WebSocketProviderSource<fearless.StringScaleMapper<UInt32>>(
            itemIdentifier: "era", codingPath: .currentEra, keyOperationClosure: { _ in ClosureOperation { [key] } },
            runtimeService: runtime, engine: engine, trigger: DataProviderProxyTrigger(), operationManager: OperationManager()
        )
        waitUntil { engine.isSubscribed }
        runtime.failure = NSError(domain: "CovG.runtime", code: 65)
        XCTAssertThrowsError(try CovGOperationFixtures.run(source.fetchOperation(by: "era"))) { XCTAssertEqual(($0 as NSError).code, 65) }
    }

    private func update(key: Data, value: String?) -> String {
        let change = value.map { "\"\($0)\"" } ?? "null"
        return """
        {"jsonrpc":"2.0","method":"state_storage","params":{"subscription":"s",
        "result":{"block":"0x01","changes":[["\(key.toHex(includePrefix: true))",\(change)]]}}}
        """
    }

    private func waitUntil(_ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate())
    }
}

final class CovGTriggerCounter: DataProviderTriggerDelegate {
    private let lock = NSLock()
    private var value = 0
    var count: Int {
        lock.lock(); defer { lock.unlock() }; return value
    }

    func didTrigger() {
        lock.lock(); value += 1; lock.unlock()
    }
}

final class CovGFailingRuntimeService: RuntimeCodingServiceProtocol {
    var failure: Error?
    var snapshot: RuntimeSnapshot? { nil }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let failure = self.failure
        return ClosureOperation {
            if let failure {
                throw failure
            }
            return try RuntimeCodingServiceStub.createWestendCodingFactory()
        }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        try RuntimeCodingServiceStub.createWestendCodingFactory()
    }
}

final class CovGSubscriptionEngine: JSONRPCEngine {
    static let subscriptionId: UInt16 = 7
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] {
        []
    }

    var subscribeError: Error?
    private let lock = NSLock()
    private var deliver: ((Data) throws -> Void)?
    private var fail: ((Error) -> Void)?
    private var storedMethod: String?
    private var storedParameters: String?
    private var storedUnsubscribed: [UInt16] = []

    var isSubscribed: Bool {
        lock.lock(); defer { lock.unlock() }; return deliver != nil
    }

    var method: String? {
        lock.lock(); defer { lock.unlock() }; return storedMethod
    }

    var parameters: String? {
        lock.lock(); defer { lock.unlock() }; return storedParameters
    }

    var unsubscribed: [UInt16] {
        lock.lock(); defer { lock.unlock() }; return storedUnsubscribed
    }

    func subscribe<P: Codable, T: Decodable>(
        _ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        if let subscribeError {
            throw subscribeError
        }
        let encoded = try params.map { try JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        lock.lock()
        storedMethod = method
        storedParameters = encoded
        deliver = { data in updateClosure(try JSONDecoder().decode(T.self, from: data)) }
        fail = { failureClosure($0, false) }
        lock.unlock()
        return Self.subscriptionId
    }

    func send(_ json: String) throws {
        lock.lock(); let current = deliver; lock.unlock()
        try XCTUnwrap(current)(Data(json.utf8))
    }

    func failSubscription(_ error: Error) {
        lock.lock(); let current = fail; lock.unlock()
        current?(error)
    }

    func callMethod<P: Codable, T: Decodable>(
        _: String, params _: P?, options _: JSONRPCOptions, completion _: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        throw NSError(domain: "CovG.unexpectedCall", code: 1)
    }

    func generateRequestId() -> UInt16 {
        1
    }

    func cancelForIdentifier(_: UInt16) {}
    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url: URL) {
        self.url = url
    }

    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {
        lock.lock(); storedUnsubscribed.append(identifier); lock.unlock()
    }
}
