import BigInt
@testable import fearless
import Foundation
import RobinHood
import SSFModels
import SSFUtils
import XCTest

final class CovGPolkaswapTests: XCTestCase {
    private let params = PolkaswapQuoteParams(
        fromAssetId: "from",
        toAssetId: "to",
        amount: "53",
        swapVariant: .desiredInput,
        liquiditySources: ["XYKPool"],
        filterMode: .allowSelected
    )

    func testSwapAvailabilityMarketAndQuoteRPCParametersAndResults() throws {
        let engine = CovGRPCEngine()
        engine.responses = [RPCMethod.checkIsSwapPossible: Data("true".utf8), RPCMethod.availableMarketAlgorithms: Data(#"["XYKPool"]"#.utf8),
                            RPCMethod.recalculateSwapValues: Data(#"{"amount":"55","rewards":["reward"]}"#.utf8)]
        let registry = try CovGPoolRegistry()
        registry.connection = engine
        let factory = PolkaswapOperationFactory(storageRequestFactory: CovGPoolStorage(), chainRegistry: registry, chainId: "1")
        let availability = try CovGOperationFixtures.run(factory.createIsPathAvalableAndMarketCompoundOperation(dexId: 7, from: "from", to: "to"))
        XCTAssertTrue(availability.isAvailable)
        XCTAssertEqual(availability.markets, ["XYKPool"])
        let quote = try CovGOperationFixtures.run(factory.createPolkaswapQuoteOperation(dexId: 7, params: params))
        XCTAssertEqual(quote.amount, "55")
        XCTAssertEqual(quote.rewards, ["reward"])
        for method in [RPCMethod.checkIsSwapPossible, RPCMethod.availableMarketAlgorithms] {
            let data = try XCTUnwrap(engine.requests.first { $0.0 == method }?.1)
            XCTAssertEqual(String(data: data, encoding: .utf8), #"[7,"from","to"]"#)
        }
        let data = try XCTUnwrap(engine.requests.first { $0.0 == RPCMethod.recalculateSwapValues }?.1)
        XCTAssertEqual(String(data: data, encoding: .utf8), #"[7,"from","to","53","WithDesiredInput",["XYKPool"],"AllowSelected"]"#)
    }

    func testUnavailableConnectionAndRuntimeFailEveryOperation() throws {
        let registry = try CovGPoolRegistry()
        registry.connection = nil
        let factory = PolkaswapOperationFactory(storageRequestFactory: CovGPoolStorage(), chainRegistry: registry, chainId: "1")
        XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createIsPathAvailableOperation(dexId: 0, from: "a", to: "b")))
        XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createGetAvailableMarketAlgorithmsOperation(dexId: 0, from: "a", to: "b")))
        XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createPolkaswapQuoteOperation(dexId: 0, params: params)))
        XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createDexInfosOperation()))
        var result: Result<SwapValues, Error>?
        factory.fetchQuote(dexId: 0, params: params, timeout: 1) { result = $0 }
        XCTAssertThrowsError(try XCTUnwrap(result).get()) { XCTAssertTrue($0 is ChainRegistryError) }
        registry.provider = nil
        XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createDexInfosOperation()))
    }

    func testQuoteImmediateSuccessThrownErrorsAndTimeoutHaveSingleCompletion() throws {
        let engine = CovGRPCEngine()
        let registry = try CovGPoolRegistry()
        registry.connection = engine
        let factory = PolkaswapOperationFactory(storageRequestFactory: CovGPoolStorage(), chainRegistry: registry, chainId: "1")
        engine.responses[RPCMethod.recalculateSwapValues] = Data(#"{"amount":"55","rewards":[]}"#.utf8)
        var received: [Result<SwapValues, Error>] = []
        factory.fetchQuote(dexId: 0, params: params, timeout: 0.05) { received.append($0) }
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(try received.first?.get().amount, "55")
        engine.failure = NSError(domain: "CovG.rpc", code: 91)
        factory.fetchQuote(dexId: 0, params: params, timeout: 0.05) { received.append($0) }
        XCTAssertEqual(received.count, 2)
        XCTAssertThrowsError(try received[1].get()) { XCTAssertEqual(($0 as NSError).code, 91) }
        engine.failure = nil
        engine.silent = true
        let done = expectation(description: "quote timeout")
        factory.fetchQuote(dexId: 0, params: params, timeout: 0.05) { result in
            if case let .failure(error) = result {
                XCTAssertTrue(error is JSONRPCEngineError)
            } else {
                XCTFail("Expected a timeout")
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        let deadline = Date().addingTimeInterval(5)
        while engine.cancelled.isEmpty, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertEqual(engine.cancelled.count, 1)
        XCTAssertEqual(received.count, 2)
        let reply = PolkaswapQuoteReply { result in XCTAssertEqual(try? result.get().amount, "1") }
        XCTAssertTrue(reply.finish(.success(SwapValues(dexId: nil, amount: "1", rewards: []))))
        XCTAssertFalse(reply.finish(.failure(NSError(domain: "CovG.late", code: 1))))
    }

    func testPolkaswapJSONRoundTripsEverySupportedValueAndNull() throws {
        let values = [PolkaswapJSON(UInt32(7)), PolkaswapJSON("token"), PolkaswapJSON(true), PolkaswapJSON(2.5), PolkaswapJSON(["one", "two"])]
        let expected = ["7", #""token""#, "true", "2.5", #"["one","two"]"#]
        for (value, json) in zip(values, expected) {
            let data = try JSONEncoder().encode(value)
            XCTAssertEqual(String(data: data, encoding: .utf8), json)
            let decoded = try JSONDecoder().decode(PolkaswapJSON.self, from: data)
            XCTAssertNotNil(decoded.value())
            XCTAssertEqual(try JSONEncoder().encode(decoded), data)
        }
        let null = try JSONDecoder().decode(PolkaswapJSON.self, from: Data("null".utf8))
        XCTAssertNil(null.value())
        XCTAssertEqual(try JSONEncoder().encode(null), Data("null".utf8))
    }

    func testSwapAmountsAndAssetIdentifiersUseRuntimeJSONShapes() throws {
        let input = SwapAmount(type: .desiredInput, desired: 10, slip: 9)
        let output = SwapAmount(type: .desiredOutput, desired: 10, slip: 11)
        let inputJSON = try JSONDecoder().decode([String: String].self, from: JSONEncoder().encode(input))
        XCTAssertEqual(inputJSON, ["desiredAmountIn": "10", "minAmountOut": "9"])
        let outputJSON = try JSONDecoder().decode([String: String].self, from: JSONEncoder().encode(output))
        XCTAssertEqual(outputJSON, ["desiredAmountOut": "10", "maxAmountIn": "11"])
        let decoded = try JSONDecoder().decode(SwapAmount.self, from: JSONEncoder().encode(input))
        XCTAssertEqual(decoded.desired, 10)
        XCTAssertEqual(decoded.slip, 9)
        XCTAssertEqual(decoded.type, .desiredInput)
        let decodedOutput = try JSONDecoder().decode(SwapAmount.self, from: JSONEncoder().encode(output))
        XCTAssertEqual(decodedOutput.type, .desiredOutput)
        XCTAssertEqual(decodedOutput.desired, 11)
        XCTAssertEqual(decodedOutput.slip, 10)
        XCTAssertThrowsError(try JSONDecoder().decode(SwapAmount.self, from: Data("{}".utf8)))
        let id = fearless.SoraAssetId(wrappedValue: "0x0102ff")
        XCTAssertEqual(try JSONDecoder().decode([String: [String]].self, from: JSONEncoder().encode(id)), ["code": ["1", "2", "255"]])
        let readId = try JSONDecoder().decode(fearless.SoraAssetId.self, from: Data(#"{"code":"AQL/"}"#.utf8))
        XCTAssertEqual(readId.value, "0x0102ff")
        XCTAssertThrowsError(try JSONEncoder().encode(fearless.SoraAssetId(wrappedValue: "invalid")))
        let bytes = try JSONDecoder().decode(fearless.ArrayCodable.self, from: Data(#"["1","2","255"]"#.utf8))
        XCTAssertEqual(bytes.wrappedValue, "0x0102ff")
        XCTAssertEqual(try JSONEncoder().encode(bytes), Data(#"["1","2","255"]"#.utf8))
        XCTAssertThrowsError(try JSONEncoder().encode(fearless.ArrayCodable(wrappedValue: "invalid")))
        let mode = try JSONDecoder().decode(PolkaswapCallFilterModeType.self, from: Data(#"["AllowSelected","7"]"#.utf8))
        XCTAssertEqual(mode.name, "AllowSelected")
        XCTAssertEqual(mode.value, 7)
        XCTAssertEqual(try JSONEncoder().encode(mode), Data(#"["AllowSelected",null]"#.utf8))
        let fallback = try JSONDecoder().decode(PolkaswapCallFilterModeType.self, from: Data(#"["Disabled",7]"#.utf8))
        XCTAssertEqual(fallback.name, "Disabled")
        XCTAssertNil(fallback.value)
    }
}

final class CovGRPCEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] {
        []
    }

    var responses: [String: Data] = [:]
    var handler: ((String, Data?) throws -> Data)?
    var failure: Error?
    var silent = false
    private let lock = NSLock()
    private var nextId: UInt16 = 0
    private var recorded: [(String, Data?)] = []
    private var cancellations: [UInt16] = []
    var requests: [(String, Data?)] {
        lock.lock(); defer { lock.unlock() }; return recorded
    }

    var cancelled: [UInt16] {
        lock.lock(); defer { lock.unlock() }; return cancellations
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String, params: P?, options _: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        if let failure {
            throw failure
        }
        let payload = try params.map { try JSONEncoder().encode($0) }
        lock.lock(); recorded.append((method, payload)); lock.unlock()
        let identifier = generateRequestId()
        if !silent {
            do { try closure?(.success(JSONDecoder().decode(T.self, from: handler?(method, payload) ?? responses[method] ?? Data("null".utf8)))) }
            catch { closure?(.failure(error)) }
        }
        return identifier
    }

    func generateRequestId() -> UInt16 {
        lock.lock(); defer { lock.unlock() }; nextId += 1; return nextId
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        lock.lock(); cancellations.append(identifier); lock.unlock()
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String, params _: P?, updateClosure _: @escaping (T) -> Void, failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        throw NSError(domain: "CovG.unexpectedSubscription", code: 1)
    }

    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url: URL) {
        self.url = url
    }

    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}
