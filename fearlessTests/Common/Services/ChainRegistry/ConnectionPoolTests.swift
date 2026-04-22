import XCTest
@testable import fearless
import Cuckoo
import SSFUtils

private final class NetworkWorkerRequestSignerStub: RequestSigner {
    private(set) var signingInvocations = 0

    func sign(request: inout URLRequest, config _: RequestConfig) throws {
        signingInvocations += 1
        request.setValue("signed", forHTTPHeaderField: "X-Signature")
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = URLProtocolStub.requestHandler else {
            fatalError("URLProtocolStub.requestHandler not set")
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

class ConnectionPoolTests: XCTestCase {
    private struct WorkerPayload: Decodable, Equatable {
        let value: String
    }

    func testSetupCreatesNewConnections() {
        do {
            // given

            let connectionFactory = MockConnectionFactoryProtocol()

            stub(connectionFactory) { stub in
                stub.createConnection(connectionName: any(), for: any(), delegate: any()).then { _ in
                    MockConnection()
                }
            }

            let connectionPool = ConnectionPool(connectionFactory: connectionFactory)

            // when

            let chainModels: [ChainModel] = ChainModelGenerator.generate(count: 10)

            let connections: [JSONRPCEngine] = try chainModels.reduce([]) { (allConnections, chain) in
                let connection = try connectionPool.setupConnection(for: chain)
                return allConnections + [connection]
            }

            // then

            let actualChainIds = Set(connectionPool.connections.map { $0.chainId })
            let expectedChainIds = Set(chainModels.map { $0.chainId })

            XCTAssertEqual(expectedChainIds, actualChainIds)
            XCTAssertEqual(connections.count, expectedChainIds.count)
        } catch {
            XCTFail("Did receive error \(error)")
        }
    }

    func testNetworkWorkerCompatibilityBuildsSignedRequestAndDecodesResponse() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let signer = NetworkWorkerRequestSignerStub()
        let worker = NetworkWorkerDefault(session: session)
        let requestBody = Data("{\"request\":\"payload\"}".utf8)

        let requestConfig = RequestConfig(
            baseURL: URL(string: "https://unit.test")!,
            method: .post,
            endpoint: "compat",
            queryItems: [URLQueryItem(name: "v", value: "1")],
            headers: [HTTPHeader(field: "X-Test", value: "yes")],
            body: requestBody
        )
        requestConfig.signingType = .custom(signer: signer)

        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://unit.test/compat?v=1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Test"), "yes")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Signature"), "signed")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data("{\"value\":\"ok\"}".utf8)
            return (response, data)
        }
        defer { URLProtocolStub.requestHandler = nil }

        let response: WorkerPayload = try await worker.performRequest(with: requestConfig)

        XCTAssertEqual(signer.signingInvocations, 1)
        XCTAssertEqual(response, WorkerPayload(value: "ok"))
    }

    func testNetworkWorkerCompatibilitySupportsRawDataResponse() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let worker = NetworkWorkerDefault(session: session)
        let requestConfig = RequestConfig(
            baseURL: URL(string: "https://unit.test")!,
            method: .get,
            endpoint: "raw",
            headers: nil,
            body: nil
        )
        let expectedData = Data("raw-bytes".utf8)

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, expectedData)
        }
        defer { URLProtocolStub.requestHandler = nil }

        let result: Data = try await worker.performRequest(with: requestConfig)

        XCTAssertEqual(result, expectedData)
    }

    func testNetworkWorkerCompatibilityUsesProvidedDecoder() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let worker = NetworkWorkerDefault(session: session)
        let requestConfig = RequestConfig(
            baseURL: URL(string: "https://unit.test")!,
            method: .get,
            endpoint: "decoder",
            headers: nil,
            body: nil
        )
        let snakeCaseDecoder = JSONDecoder()
        snakeCaseDecoder.keyDecodingStrategy = .convertFromSnakeCase
        requestConfig.decoderType = .codable(jsonDecoder: snakeCaseDecoder)

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data("{\"value_text\":\"ok\"}".utf8)
            return (response, data)
        }
        defer { URLProtocolStub.requestHandler = nil }

        struct SnakeCasePayload: Decodable, Equatable {
            let valueText: String
        }

        let result: SnakeCasePayload = try await worker.performRequest(with: requestConfig)

        XCTAssertEqual(result, SnakeCasePayload(valueText: "ok"))
    }

    func testNetworkWorkerCompatibilityCacheWrapperYieldsSingleValueAndFinishes() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let worker = NetworkWorkerDefault(session: session)
        let requestConfig = RequestConfig(
            baseURL: URL(string: "https://unit.test")!,
            method: .get,
            endpoint: "cache",
            headers: nil,
            body: nil
        )

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data("{\"value\":\"stream\"}".utf8)
            return (response, data)
        }
        defer { URLProtocolStub.requestHandler = nil }

        let stream = try await worker.performRequest(with: requestConfig, withCacheOptions: .onAll) as AsyncThrowingStream<CachedNetworkResponse<WorkerPayload>, Error>
        var collected: [WorkerPayload] = []

        for try await item in stream {
            collected.append(item.data)
        }

        XCTAssertEqual(collected, [WorkerPayload(value: "stream")])
    }

    func testNetworkWorkerCompatibilityBuildsRequestWithoutEndpoint() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let worker = NetworkWorkerDefault(session: session)
        let requestConfig = RequestConfig(
            baseURL: URL(string: "https://unit.test/base")!,
            method: .get,
            endpoint: nil,
            queryItems: [URLQueryItem(name: "q", value: "1")],
            headers: nil,
            body: nil
        )

        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://unit.test/base?q=1")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"value\":\"base\"}".utf8))
        }
        defer { URLProtocolStub.requestHandler = nil }

        let result: WorkerPayload = try await worker.performRequest(with: requestConfig)
        XCTAssertEqual(result, WorkerPayload(value: "base"))
    }

    func testEthereumConnectionPoolResetRemovesConnectionForChainId() throws {
        let chainId = "e2e-eth-test-chain"
        let chain = makeEthereumLikeChain(chainId: chainId)
        let pool = EthereumConnectionPool()

        _ = try pool.setupConnection(for: chain)

        XCTAssertNotNil(pool.getConnection(for: chainId))

        pool.resetConnection(for: chainId)

        XCTAssertNil(pool.getConnection(for: chainId))
    }

    private func makeEthereumLikeChain(chainId: String) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://rpc.unit.test")!,
            name: "Unit Test ETH Node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "Unit ETH",
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

//    func testSetupUpdatesExistingConnection() {
//        do {
//            // given
//
//            let connectionFactory = MockConnectionFactoryProtocol()
//
//            let setupConnection: () -> MockConnection = {
//                let mockConnection = MockConnection()
//                stub(mockConnection.autobalancing) { stub in
//                    stub.set(ranking: any()).thenDoNothing()
//                    stub.url.get.then { URL(string: "https://github.com") }
//                }
//
//                return mockConnection
//            }
//
//            stub(connectionFactory) { stub in
//                stub.createConnection(connectionName: any(), for: any(), delegate: any()).then { _ in
//                    setupConnection()
//                }
//            }
//
//            let connectionPool = ConnectionPool(connectionFactory: connectionFactory)
//
//            // when
//
//            let chainModels: [ChainModel] = ChainModelGenerator.generate(count: 10)
//
//            let newConnections: [MockConnection] = try chainModels.reduce(
//                []
//            ) { (allConnections, chain) in
//                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
//                    return allConnections + [connection]
//                } else {
//                    return allConnections
//                }
//            }
//            
//            let updatedConnections: [MockConnection] = try chainModels.reduce(
//                []
//            ) { (allConnections, chain) in
//                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
//                    return allConnections + [connection]
//                } else {
//                    return allConnections
//                }
//            }
//
//            // then
//
//            let actualChainIds = Set(connectionPool.connectionsByChainIds.keys)
//            let expectedChainIds = Set(chainModels.map { $0.chainId })
//
//            XCTAssertEqual(expectedChainIds, actualChainIds)
//            XCTAssertEqual(newConnections.count, updatedConnections.count)
//
//            for index in 0..<newConnections.count {
//                XCTAssertTrue(newConnections[index] === updatedConnections[index])
//                verify(newConnections[index].autobalancing, times(1)).set(ranking: any())
//            }
//        } catch {
//            XCTFail("Did receive error \(error)")
//        }
//    }
}
