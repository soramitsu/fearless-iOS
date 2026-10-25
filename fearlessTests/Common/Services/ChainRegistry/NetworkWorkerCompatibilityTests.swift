import XCTest
@testable import fearless

final class NetworkWorkerCompatibilityTests: XCTestCase {
    override func tearDown() {
        URLProtocolMock.requestHandler = nil
        super.tearDown()
    }

    func testPerformRequestAppliesSignerAndDecodesResponse() async throws {
        struct ResponseModel: Decodable, Equatable {
            let value: String
        }

        let signer = SignerSpy()
        let session = makeSession()
        let worker = NetworkWorkerDefault(session: session)

        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Signed"), "1")

            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"value":"ok"}"#.data(using: .utf8)!
            return (response, body)
        }

        let config = RequestConfig(
            baseURL: URL(string: "https://example.com")!,
            method: .get,
            endpoint: "test",
            headers: nil,
            body: nil
        )
        config.signingType = .custom(signer: signer)

        let result: ResponseModel = try await worker.performRequest(with: config)

        XCTAssertEqual(result, .init(value: "ok"))
        XCTAssertTrue(signer.didSign)
    }

    func testPerformRequestReturnsRawDataForDataType() async throws {
        let expected = Data([0x01, 0x02, 0x03, 0x04])
        let session = makeSession()
        let worker = NetworkWorkerDefault(session: session)

        URLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, expected)
        }

        let config = RequestConfig(
            baseURL: URL(string: "https://example.com")!,
            method: .get,
            endpoint: "bytes",
            headers: nil,
            body: nil
        )

        let result: Data = try await worker.performRequest(with: config)
        XCTAssertEqual(result, expected)
    }

    func testPerformRequestWithCacheOptionsYieldsSingleCachedResponse() async throws {
        struct ResponseModel: Decodable, Equatable {
            let value: Int
        }

        let session = makeSession()
        let worker = NetworkWorkerDefault(session: session)

        URLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"value":7}"#.data(using: .utf8)!
            return (response, body)
        }

        let config = RequestConfig(
            baseURL: URL(string: "https://example.com")!,
            method: .get,
            endpoint: "cached",
            headers: nil,
            body: nil
        )

        let stream = try await worker.performRequest(
            with: config,
            withCacheOptions: .onAll
        ) as AsyncThrowingStream<CachedNetworkResponse<ResponseModel>, Error>

        var values: [ResponseModel] = []
        for try await cached in stream {
            values.append(cached.data)
        }

        XCTAssertEqual(values, [.init(value: 7)])
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: configuration)
    }
}

private final class SignerSpy: RequestSigner {
    private(set) var didSign = false

    func sign(request: inout URLRequest, config _: RequestConfig) throws {
        didSign = true
        request.setValue("1", forHTTPHeaderField: "X-Signed")
    }
}

private final class URLProtocolMock: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        _ = request
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = URLProtocolMock.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "URLProtocolMock", code: 0))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
