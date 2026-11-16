@testable import fearless
import Foundation
import RobinHood
import SSFModels
import SSFUtils
import XCTest

final class CovGNetworkOperationTests: XCTestCase {
    func testHTTPRequestBuilderEscapesQueryAndOverridesDefaultHeaders() throws {
        let builder = HTTPRequestBuilder(host: "https://network.invalid/ignored", headerBuilder: CovGHeaders())
        let config = CovGRequestConfig(
            path: "/items",
            httpMethod: "POST",
            headers: ["X-Key": "custom"],
            queryParameters: [URLQueryItem(name: "q", value: "a b&c")],
            payload: Data("body".utf8)
        )
        let request = try builder.buildRequest(with: config)
        XCTAssertEqual(request.url?.host, "network.invalid")
        XCTAssertEqual(request.url?.path, "/items")
        XCTAssertEqual(try URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "a b&c")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.httpBody, Data("body".utf8))
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Key"), "custom")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        let plain = try HTTPRequestBuilder(host: "https://network.invalid").buildRequest(with: CovGRequestConfig())
        XCTAssertEqual(plain.httpMethod, "GET")
        XCTAssertNil(plain.httpBody)
    }

    func testHTTPRequestBuilderRejectsInvalidPathAndBody() throws {
        let builder = HTTPRequestBuilder(host: "https://network.invalid")
        XCTAssertThrowsError(try builder.buildRequest(with: CovGRequestConfig(path: "relative"))) {
            guard case HTTPRequestBuilderError.invalidURLPath = $0 else { return XCTFail("Wrong error \($0)") }
        }
        XCTAssertThrowsError(try builder.buildRequest(with: CovGRequestConfig(failure: NSError(domain: "CovG.body", code: 1)))) {
            guard case HTTPRequestBuilderError.invalidBody = $0 else { return XCTFail("Wrong error \($0)") }
        }
    }

    func testManualOperationTransitionsAndPreservesPresetResults() throws {
        let operation = ManualOperation<Int>()
        XCTAssertTrue(operation.isAsynchronous)
        XCTAssertFalse(operation.isFinished)
        operation.finish()
        XCTAssertFalse(operation.isFinished)
        operation.start()
        XCTAssertTrue(operation.isExecuting)
        XCTAssertFalse(operation.isFinished)
        operation.result = .success(53)
        operation.finish()
        XCTAssertFalse(operation.isExecuting)
        XCTAssertTrue(operation.isFinished)
        XCTAssertEqual(try CovGOperationFixtures.result(operation), 53)
        let ready = ManualOperation<Int>()
        ready.result = .success(54)
        ready.start()
        XCTAssertTrue(ready.isFinished)
        XCTAssertEqual(try CovGOperationFixtures.result(ready), 54)
        let cancelled = ManualOperation<Int>()
        cancelled.cancel()
        cancelled.start()
        XCTAssertTrue(cancelled.isFinished)
        XCTAssertFalse(cancelled.isExecuting)
    }

    func testJSONSourceDecodesPayloadAndPropagatesInvalidData() throws {
        let source = try JsonSingleProviderSource<[String: Int]>(url: XCTUnwrap(URL(string: "https://json.invalid")))
        let wrapper = source.fetchOperation()
        let network = try CovGOperationFixtures.network(wrapper, as: Data.self)
        network.result = .success(Data(#"{"value":53}"#.utf8))
        XCTAssertEqual(try CovGOperationFixtures.run(wrapper), ["value": 53])
        let invalid = source.fetchOperation()
        let invalidNetwork = try CovGOperationFixtures.network(invalid, as: Data.self)
        invalidNetwork.result = .success(Data("invalid".utf8))
        XCTAssertThrowsError(try CovGOperationFixtures.run(invalid))
    }

    func testAccountOperationsEncodeBlockNumbersAndMapFirstStorageResult() throws {
        let engine = CovGRPCEngine()
        engine.responses[RPCMethod.getBlockHash] = Data(#""0xabcdef""#.utf8)
        let registry = try CovGPoolRegistry()
        registry.connection = engine
        let storage = CovGPoolStorage()
        let factory = AccountOperationFactory(requestFactory: storage, chainRegistry: registry, chainId: "1")
        XCTAssertEqual(try CovGOperationFixtures.run(factory.createGenisisHashOperation()), "0xabcdef")
        XCTAssertEqual(try CovGOperationFixtures.run(factory.createBlockHashOperation(258)), "0xabcdef")
        XCTAssertEqual(engine.requests.compactMap { $0.1.flatMap { String(data: $0, encoding: .utf8) } }, [#"["0x00000000"]"#, #"["0x00000102"]"#])
        let info = AccountInfo(ethBalance: 53)
        storage.responses["Account"] = try [JSONEncoder().encode(info)]
        let account = Data(repeating: 1, count: 32)
        XCTAssertEqual(try CovGOperationFixtures.run(factory.createAccountInfoFetchOperation(account)), info)
        XCTAssertEqual(storage.parameters.last, try JSONEncoder().encode([account]))
        storage.responses["Account"] = []
        XCTAssertNil(try CovGOperationFixtures.run(factory.createAccountInfoFetchOperation(account)))
        registry.provider = nil
        XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createAccountInfoFetchOperation(account)))
        registry.connection = nil
        XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createAccountInfoFetchOperation(account)))
        XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createGenisisHashOperation()))
    }
}

private struct CovGRequestConfig: HTTPRequestConfig {
    var path = "/items"
    var httpMethod = "GET"
    var headers: [String: String]?
    var queryParameters: [URLQueryItem]?
    var payload: Data?
    var failure: Error?
    func body() throws -> Data? {
        if let failure {
            throw failure
        }; return payload
    }
}

private struct CovGHeaders: HTTPHeadersBuilderProtocol {
    func buildHeaders() -> [String: String]? {
        ["Accept": "application/json", "X-Key": "default"]
    }
}
