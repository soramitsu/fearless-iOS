import RobinHood
import SSFUtils
import XCTest
@testable import fearless

final class CovFRtMortalEraTests: XCTestCase {
    func testEraUsesBestBlockWhenFinalityLagsAndRuntimeMinimumPeriod() throws {
        let engine = CovFRtMethodEngine { method, params in
            switch (method, params.first) {
            case (RPCMethod.getFinalizedBlockHash, _): return "0xfinal"
            case (RPCMethod.getBlockHeader, "0xfinal"?): return covFRtHeader(number: "0x64", parent: "0xp0")
            case (RPCMethod.getBlockHeader, "0xparent"?): return covFRtHeader(number: "0x6d", parent: "0xp1")
            case (RPCMethod.getBlockHeader, nil): return covFRtHeader(number: "0x6e", parent: "0xparent")
            default: throw NSError(domain: "unexpected \(method)", code: 1)
            }
        }
        let era = try CovFFixtures.execute(MortalEraOperationFactory().createOperation(from: engine, runtimeService: covFRtBareRuntime()))
        XCTAssertEqual(era.blockNumber, 109)
        guard case let .mortal(period, phase) = era.extrinsicEra else {
            return XCTFail("Expected a mortal era")
        }
        XCTAssertEqual(period, 64)
        XCTAssertEqual(phase, 45)
        XCTAssertEqual(Set(engine.methods), [RPCMethod.getFinalizedBlockHash, RPCMethod.getBlockHeader])
    }

    func testEraUsesFinalizedBlockWithinLagAndGenesisBestHeader() throws {
        for (best, expected) in [("0x66", UInt32(100)), ("0x60", UInt32(100))] {
            let engine = CovFRtMethodEngine { method, params in
                switch (method, params.first) {
                case (RPCMethod.getFinalizedBlockHash, _): return "0xfinal"
                case (RPCMethod.getBlockHeader, "0xfinal"?): return covFRtHeader(number: "0x64", parent: "0xp0")
                case (RPCMethod.getBlockHeader, nil): return covFRtHeader(number: best, parent: "")
                default: throw NSError(domain: "unexpected \(method)", code: 1)
                }
            }
            let era = try CovFFixtures.execute(
                MortalEraOperationFactory().createOperation(from: engine, runtimeService: try covFRtBareRuntime())
            )
            XCTAssertEqual(era.blockNumber, expected)
        }
    }

    func testNodeFailuresFailTheEraButRuntimeFailureFallsBackToDefaults() throws {
        let failing = CovFRtMethodEngine { _, _ in throw NSError(domain: "node", code: 2) }
        XCTAssertThrowsError(
            try CovFFixtures.execute(MortalEraOperationFactory().createOperation(from: failing, runtimeService: try covFRtBareRuntime()))
        )
        let malformed = CovFRtMethodEngine { method, _ in
            method == RPCMethod.getFinalizedBlockHash ? "0xfinal" as Any : covFRtHeader(number: "zz", parent: "") as Any
        }
        XCTAssertThrowsError(
            try CovFFixtures.execute(MortalEraOperationFactory().createOperation(from: malformed, runtimeService: try covFRtBareRuntime()))
        )
        let runtime = try covFRtBareRuntime()
        runtime.failure = NSError(domain: "runtime", code: 3)
        let healthy = CovFRtMethodEngine { method, _ in
            method == RPCMethod.getFinalizedBlockHash ? "0xfinal" as Any : covFRtHeader(number: "0x10", parent: "") as Any
        }
        let era = try CovFFixtures.execute(MortalEraOperationFactory().createOperation(from: healthy, runtimeService: runtime))
        XCTAssertEqual(era.blockNumber, 16)
        guard case let .mortal(period, phase) = era.extrinsicEra else {
            return XCTFail("Expected a mortal era")
        }
        XCTAssertEqual(period, 64)
        XCTAssertEqual(phase, 16)
    }

    func testRuntimeWithoutConstantsFallsBackToDefaultPeriodAndHashCount() throws {
        let runtime = try covFRtBareRuntime()
        let engine = CovFRtMethodEngine { method, _ in
            method == RPCMethod.getFinalizedBlockHash ? "0xfinal" as Any : covFRtHeader(number: "0x3e8", parent: "") as Any
        }
        let era = try CovFFixtures.execute(MortalEraOperationFactory().createOperation(from: engine, runtimeService: runtime))
        guard case let .mortal(period, _) = era.extrinsicEra else {
            return XCTFail("Expected a mortal era")
        }
        XCTAssertEqual(period, 64)
        XCTAssertEqual(era.blockNumber, 1000)
    }
}

/// A runtime without Babe, Timestamp or System constants: the factory must use its fallbacks.
func covFRtBareRuntime() throws -> CovFRuntime {
    try CovFFixtures.runtime(path: .activeEra, type: "u32", definitions: #"{"types":{}}"#)
}

func covFRtHeader(number: String, parent: String) -> [String: Any] {
    ["digest": ["logs": [String]()], "extrinsicsRoot": "0x00", "number": number, "stateRoot": "0x00", "parentHash": parent]
}

/// Answers each JSON-RPC call through a closure of (method, string parameters).
final class CovFRtMethodEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    private let lock = NSLock()
    private var storedMethods: [String] = []
    private var identifier: UInt16 = 0
    private let handler: (String, [String]) throws -> Any

    init(handler: @escaping (String, [String]) throws -> Any) { self.handler = handler }

    var methods: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedMethods
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String, params: P?, options _: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        lock.lock()
        storedMethods.append(method)
        lock.unlock()
        let strings: [String]
        if let params, let decoded = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(params)) as? [Any] {
            strings = decoded.compactMap { $0 as? String }
        } else {
            strings = []
        }
        do {
            let value = try handler(method, strings)
            let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
            closure?(.success(try JSONDecoder().decode(T.self, from: data)))
        } catch {
            closure?(.failure(error))
        }
        return generateRequestId()
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String, params _: P?, updateClosure _: @escaping (T) -> Void, failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        generateRequestId()
    }

    func generateRequestId() -> UInt16 {
        lock.lock()
        defer { lock.unlock() }
        identifier += 1
        return identifier
    }

    func cancelForIdentifier(_: UInt16) {}
    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}
