import SSFPolkaswap
import SSFPools
import XCTest

/// The pool APY query used to run inside the closed-source `sorawallet` framework. These tests
/// pin the open Swift replacement: fixed indexer host, bounded pagination, tolerant value parsing
/// and the mapping from indexer pool ids to the reserves addresses the screens compare against.
final class LiquidityPoolsListTests: XCTestCase {
    private let indexer = URL(string: "https://pi.soramitsu.io/graphql")!
    private let retiredSubquery = URL(string: "https://api.subquery.network/sq/sora-xor/sora-prod")!
    private let base = "0x0200000000000000000000000000000000000000000000000000000000000000"
    private let target = "0x0200050000000000000000000000000000000000000000000000000000000000"
    private let otherTarget = "0x0200040000000000000000000000000000000000000000000000000000000000"

    override func tearDown() {
        PoolApyURLProtocolMock.requestHandler = nil
        PoolApyURLProtocolMock.requestCount = 0
        super.tearDown()
    }

    func testDefaultEndpointIsTheSoramitsuIndexerAndNotTheRetiredSubquery() {
        XCTAssertEqual(PolkaswapAPYWorkerDefault.soraIndexerURL, indexer)
        XCTAssertNotEqual(PolkaswapAPYWorkerDefault.soraIndexerURL, retiredSubquery)
    }

    func testRequestsFirstPageAndParsesStringAndNumberValues() async throws {
        PoolApyURLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.url, self.indexer)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try Self.jsonBody(request)
            XCTAssertEqual(body["operationName"] as? String, "FearlessPoolStrategicBonusApy")
            let query = try XCTUnwrap(body["query"] as? String)
            XCTAssertTrue(query.contains("poolXYKs("))
            XCTAssertTrue(query.contains("strategicBonusApy"))
            let variables = try XCTUnwrap(body["variables"] as? [String: Any])
            XCTAssertEqual(variables["first"] as? Int, 100)
            XCTAssertTrue(variables["after"] is NSNull)

            return try Self.page(
                nodes: [
                    ["id": "\(self.base)-\(self.target)", "strategicBonusApy": "0.125"],
                    ["id": "\(self.base)-\(self.otherTarget)", "strategicBonusApy": 0.5]
                ],
                hasNextPage: false,
                endCursor: nil
            )
        }

        let values = try await makeWorker().getAPYInfo()

        XCTAssertEqual(
            values,
            [
                PolkaswapPoolStrategicBonusApy(id: "\(base)-\(target)", strategicBonusApy: Decimal(string: "0.125")),
                PolkaswapPoolStrategicBonusApy(id: "\(base)-\(otherTarget)", strategicBonusApy: Decimal(string: "0.5"))
            ]
        )
    }

    func testFollowsCursorAndRejectsRepeatedCursor() async throws {
        var cursors: [Any] = []
        PoolApyURLProtocolMock.requestHandler = { request in
            let variables = try XCTUnwrap(Self.jsonBody(request)["variables"] as? [String: Any])
            cursors.append(variables["after"] ?? NSNull())
            return try Self.page(
                nodes: [["id": "pool-\(cursors.count)", "strategicBonusApy": "0"]],
                hasNextPage: true,
                endCursor: "cursor-1"
            )
        }

        do {
            _ = try await makeWorker().getAPYInfo()
            XCTFail("A repeated cursor must stop the read")
        } catch {
            XCTAssertEqual(error as? PolkaswapAPYWorkerError, .invalidPagination)
        }

        XCTAssertEqual(cursors.count, 2)
        XCTAssertTrue(cursors.first is NSNull)
        XCTAssertEqual(cursors.last as? String, "cursor-1")
    }

    func testRefusesEveryOtherEndpointBeforeAnyNetworkAccess() async {
        PoolApyURLProtocolMock.requestHandler = { _ in
            XCTFail("No request may leave for a refused endpoint")
            return try Self.page(nodes: [], hasNextPage: false, endCursor: nil)
        }

        let refused = [
            retiredSubquery,
            URL(string: "http://pi.soramitsu.io/graphql")!,
            URL(string: "https://pi.soramitsu.io.example.com/graphql")!,
            URL(string: "https://user@pi.soramitsu.io/graphql")!,
            URL(string: "https://pi.soramitsu.io:8443/graphql")!
        ]

        for endpoint in refused {
            do {
                _ = try await makeWorker(endpoint: endpoint).getAPYInfo()
                XCTFail("\(endpoint) must be refused")
            } catch {
                XCTAssertEqual(error as? PolkaswapAPYWorkerError, .invalidEndpoint)
            }
        }

        XCTAssertEqual(PoolApyURLProtocolMock.requestCount, 0)
    }

    func testImplausibleValuesAreShownAsNoApyInsteadOfFailingTheList() async throws {
        PoolApyURLProtocolMock.requestHandler = { _ in
            try Self.page(
                nodes: [
                    ["id": "p1", "strategicBonusApy": "-1"],
                    ["id": "p2", "strategicBonusApy": "1e9"],
                    ["id": "p3", "strategicBonusApy": "NaN"],
                    ["id": "p4", "strategicBonusApy": NSNull()],
                    ["id": "p5"],
                    ["id": "p6", "strategicBonusApy": "12 %"],
                    ["id": "p7", "strategicBonusApy": "0"]
                ],
                hasNextPage: false,
                endCursor: nil
            )
        }

        let values = try await makeWorker().getAPYInfo()

        XCTAssertEqual(values.map(\.id), ["p1", "p2", "p3", "p4", "p5", "p6", "p7"])
        XCTAssertEqual(values.map(\.strategicBonusApy), [nil, nil, nil, nil, nil, nil, Decimal(0)])
    }

    func testIndexerErrorsStatusCodesAndBadIdentifiersFail() async throws {
        let badIdentifier = try Self.pageCase(
            nodes: [["id": "a b", "strategicBonusApy": "0"]],
            error: .invalidResponse
        )
        let duplicateIdentifier = try Self.pageCase(
            nodes: [["id": "dup", "strategicBonusApy": "0"], ["id": "DUP", "strategicBonusApy": "0"]],
            error: .invalidResponse
        )
        let cases: [(HTTPURLResponse, Data, PolkaswapAPYWorkerError)] = [
            (Self.response(status: 503), Data(#"{"message":"failure to get a peer"}"#.utf8), .invalidStatusCode(503)),
            (Self.response(status: 200), Data(#"{"errors":[{"message":"boom"}]}"#.utf8), .indexerError),
            (Self.response(status: 200), Data("not json".utf8), .invalidResponse),
            badIdentifier,
            duplicateIdentifier
        ]

        for (response, data, expected) in cases {
            PoolApyURLProtocolMock.requestHandler = { _ in (response, data) }
            do {
                _ = try await makeWorker().getAPYInfo()
                XCTFail("Expected \(expected)")
            } catch {
                XCTAssertEqual(error as? PolkaswapAPYWorkerError, expected)
            }
        }
    }

    func testMapperUsesTheChainReservesAddressForIndexerPairIds() {
        let reservesAddress = "cnTkNjrs9F3YUoQkwgwHRzcFMvFpmMdmxjAFnWnd3jaJwzmKP"
        let legacyReservesAddress = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        let pools = [
            LiquidityPair(
                pairId: "\(base)-\(target)",
                chainId: nil,
                baseAssetId: base,
                targetAssetId: target,
                reservesId: reservesAddress
            ),
            LiquidityPair(
                pairId: "\(base)-\(otherTarget)",
                chainId: nil,
                baseAssetId: base,
                targetAssetId: otherTarget,
                reservesId: legacyReservesAddress
            )
        ]
        let values = [
            PolkaswapPoolStrategicBonusApy(id: "\(base)-\(target)".uppercased().replacingOccurrences(of: "0X", with: "0x"), strategicBonusApy: Decimal(string: "0.25")),
            PolkaswapPoolStrategicBonusApy(id: legacyReservesAddress, strategicBonusApy: Decimal(string: "0.5")),
            PolkaswapPoolStrategicBonusApy(id: "\(base)-0x0300000000000000000000000000000000000000000000000000000000000000", strategicBonusApy: Decimal(1)),
            PolkaswapPoolStrategicBonusApy(id: "\(base)-\(target)", strategicBonusApy: Decimal(9))
        ]

        let mapped = PolkaswapPoolApyMapper.map(values, availablePools: pools)

        XCTAssertEqual(mapped.map(\.poolId), [reservesAddress, legacyReservesAddress])
        XCTAssertEqual(mapped.map(\.apy), [Decimal(string: "0.25"), Decimal(string: "0.5")])
    }

    // MARK: - Helpers

    private func makeWorker(endpoint: URL? = nil) -> PolkaswapAPYWorkerDefault {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PoolApyURLProtocolMock.self]
        return PolkaswapAPYWorkerDefault(
            endpoint: endpoint ?? indexer,
            session: URLSession(configuration: configuration)
        )
    }

    private static func response(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://pi.soramitsu.io/graphql")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private static func page(
        nodes: [[String: Any]],
        hasNextPage: Bool,
        endCursor: String?
    ) throws -> (HTTPURLResponse, Data) {
        let pageInfo: [String: Any] = [
            "hasNextPage": hasNextPage,
            "endCursor": endCursor ?? NSNull()
        ]
        let json: [String: Any] = [
            "data": ["entities": ["nodes": nodes, "pageInfo": pageInfo]]
        ]
        return (response(status: 200), try JSONSerialization.data(withJSONObject: json))
    }

    private static func pageCase(
        nodes: [[String: Any]],
        error: PolkaswapAPYWorkerError
    ) throws -> (HTTPURLResponse, Data, PolkaswapAPYWorkerError) {
        let (response, data) = try page(nodes: nodes, hasNextPage: false, endCursor: nil)
        return (response, data, error)
    }

    private static func jsonBody(_ request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let body = request.httpBody {
            data = body
        } else {
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var collected = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count > 0 {
                    collected.append(buffer, count: count)
                } else if count == 0 {
                    break
                } else {
                    throw stream.streamError ?? URLError(.cannotDecodeRawData)
                }
            }
            data = collected
        }

        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class PoolApyURLProtocolMock: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requestCount = 0

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestCount += 1

        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "PoolApyURLProtocolMock", code: 1))
            return
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
