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
            XCTAssertEqual(request.httpMethod, HttpMethod.post.rawValue)
            XCTAssertEqual(request.url?.absoluteString, "https://unit.test/compat?v=1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Test"), "yes")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Signature"), "signed")
            XCTAssertEqual(request.httpBody, requestBody)

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
