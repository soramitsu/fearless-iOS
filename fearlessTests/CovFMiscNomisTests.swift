import XCTest
@testable import fearless

final class CovFMiscNomisTests: XCTestCase {
    override func tearDown() {
        CovFMiscURLProtocol.reset()
        super.tearDown()
    }

    func testFetchStatisticsRequestsScoreForAddressAndDecodesResponse() async throws {
        CovFMiscURLProtocol.respond(status: 200, json: ["data": ["score": 0.75, "address": "0xabc"]])
        let fetcher = NomisAccountStatisticsFetcher(networkWorker: covFMiscWorker(), signer: NomisRequestSigner())
        let response = try await fetcher.fetchStatistics(address: "0xabc")
        XCTAssertEqual(NSDecimalNumber(decimal: try XCTUnwrap(response?.data?.score)).doubleValue, 0.75, accuracy: 1e-9)
        XCTAssertEqual(response?.data?.address, "0xabc")
        let request = try XCTUnwrap(CovFMiscURLProtocol.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, ApplicationConfig.shared.nomisAccountScoreURL.appendingPathComponent("0xabc/score").absoluteString)
    }

    func testSubscriptionYieldsOneValueThenFinishes() async throws {
        CovFMiscURLProtocol.respond(status: 200, json: ["data": ["score": 0.1]])
        let fetcher = NomisAccountStatisticsFetcher(networkWorker: covFMiscWorker(), signer: NomisRequestSigner())
        var scores: [Double] = []
        for try await value in try await fetcher.subscribeForStatistics(address: "0xdef") {
            scores.append(NSDecimalNumber(decimal: value.data?.score ?? -1).doubleValue)
        }
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores.first ?? -1, 0.1, accuracy: 1e-9)
        XCTAssertTrue(CovFMiscURLProtocol.requests.first?.url?.path.hasSuffix("0xdef/score") == true)
    }

    func testHttpFailureEndsSubscriptionAndFetchWithStatusError() async throws {
        CovFMiscURLProtocol.respond(status: 503, json: ["error": "busy"])
        let fetcher = NomisAccountStatisticsFetcher(networkWorker: covFMiscWorker(), signer: NomisRequestSigner())
        do {
            _ = try await fetcher.fetchStatistics(address: "0x1")
            XCTFail("Expected status error")
        } catch let NetworkWorkerDefault.NetworkWorkerError.httpStatusCode(code, _) {
            XCTAssertEqual(code, 503)
        }
        var thrown: Error?
        do {
            for try await _ in try await fetcher.subscribeForStatistics(address: "0x2") {
                XCTFail("No value expected")
            }
        } catch { thrown = error }
        guard case let .httpStatusCode(code, _)? = thrown as? NetworkWorkerDefault.NetworkWorkerError else {
            return XCTFail("Unexpected \(String(describing: thrown))")
        }
        XCTAssertEqual(code, 503)
    }

    func testUnconfiguredSignerSendsNoNomisHeaders() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://nomis.invalid/score")))
        let config = try NomisAccountStatisticsRequest(baseURL: try XCTUnwrap(URL(string: "https://nomis.invalid")), address: "a", endpoint: "score")
        try NomisRequestSigner(clientId: "", apiKey: "  ").sign(request: &request, config: config)
        XCTAssertNil(request.value(forHTTPHeaderField: "X-ClientId"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-API-Key"))
    }

    func testSignerAddsClientAndApiKeyHeaders() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://nomis.invalid/score")))
        let config = try NomisAccountStatisticsRequest(baseURL: try XCTUnwrap(URL(string: "https://nomis.invalid")), address: "a", endpoint: "score")
        try NomisRequestSigner(clientId: "fixture-client", apiKey: " fixture-key ").sign(request: &request, config: config)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-ClientId"), "fixture-client")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "fixture-key")
        XCTAssertEqual(config.endpoint, "a/score")
        XCTAssertNil(config.body)
    }

    /// The decoder's formatter follows the device calendar (see the lane report), so the fields are read back with it.
    func testDecoderReadsMicrosecondTimestampFields() throws {
        let data = Data(#"{"date":"2024-01-02T03:04:05.250000+0000"}"#.utf8)
        let decoded = try NomisJSONDecoder().decode(CovFMiscDated.self, from: data)
        var calendar = Calendar.current
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: decoded.date)
        XCTAssertEqual([parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second], [2024, 1, 2, 3, 4, 5])
        XCTAssertEqual(Double(parts.nanosecond ?? 0) / 1e9, 0.25, accuracy: 0.001)
        XCTAssertThrowsError(try NomisJSONDecoder().decode(CovFMiscDated.self, from: Data(#"{"date":"2024-01-02"}"#.utf8)))
    }
}

struct CovFMiscDated: Decodable {
    let date: Date
}

func covFMiscWorker() -> NetworkWorkerDefault {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CovFMiscURLProtocol.self]
    return NetworkWorkerDefault(session: URLSession(configuration: configuration))
}

final class CovFMiscURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var status = 200
    private static var body = Data()
    private static var recorded: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static func respond(status: Int, json: Any) {
        lock.lock()
        self.status = status
        body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        status = 200
        body = Data()
        recorded = []
        lock.unlock()
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.recorded.append(request)
        let status = Self.status
        let body = Self.body
        Self.lock.unlock()
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
