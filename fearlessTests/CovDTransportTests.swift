import Foundation
import SSFModels
import UIKit
import SSFPools
import XCTest

@testable import fearless

/// Serves canned HTTP answers for the `covd-transport.invalid` host only.
final class CovDURLProtocol: URLProtocol {
    struct CovDAnswer {
        let status: Int
        let body: Data?
        let error: Error?
    }

    private static let lock = NSLock()
    private static var answers: [String: CovDAnswer] = [:]
    private static var requests: [URLRequest] = []
    private static var rpcResults: [String: Any] = [:]
    private static var graphQL: [(String, Any)] = []
    private static var methods: [String] = []

    /// JSON-RPC requests posted to `path` are answered by method name.
    static func rpc(_ method: String, result: Any) {
        lock.lock(); rpcResults[method] = result; lock.unlock()
    }

    /// GraphQL requests are answered by the first registered keyword their query contains.
    static func graphQL(_ keyword: String, response: Any) {
        lock.lock(); graphQL.append((keyword, response)); lock.unlock()
    }

    static func recordedMethods() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return methods
    }

    static func answer(_ path: String, with answer: CovDAnswer) {
        lock.lock(); answers[path] = answer; lock.unlock()
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return requests
    }

    static func reset() {
        lock.lock(); answers = [:]; requests = []; rpcResults = [:]; graphQL = []; methods = []; lock.unlock()
    }

    private func requestBody() -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    private func routedAnswer() -> CovDAnswer? {
        let object = (try? JSONSerialization.jsonObject(with: requestBody())) as? [String: Any] ?? [:]
        if let method = object["method"] as? String {
            Self.methods.append(method)
            guard let result = Self.rpcResults[method],
                  let data = try? JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": 1, "result": result]) else {
                return nil
            }
            return CovDAnswer(status: 200, body: data, error: nil)
        }
        let query = object["query"] as? String ?? ""
        guard let match = Self.graphQL.first(where: { query.contains($0.0) }),
              let data = try? JSONSerialization.data(withJSONObject: match.1) else {
            return nil
        }
        return CovDAnswer(status: 200, body: data, error: nil)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "covd-transport.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let answer = Self.answers[request.url?.path ?? ""] ?? routedAnswer()
        Self.lock.unlock()
        guard let answer, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        if let error = answer.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let body = answer.body {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class CovDTransportTests: XCTestCase {
    override func setUp() {
        super.setUp()
        CovDURLProtocol.reset()
        URLProtocol.registerClass(CovDURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(CovDURLProtocol.self)
        CovDURLProtocol.reset()
        super.tearDown()
    }

    private func url(_ path: String) throws -> URL {
        try XCTUnwrap(URL(string: "https://covd-transport.invalid\(path)"))
    }

    func testTransportPostsJSONAndReturnsSuccessfulBodies() async throws {
        let body = Data(#"{"jsonrpc":"2.0","id":1,"result":"0x1"}"#.utf8)
        CovDURLProtocol.answer("/rpc", with: .init(status: 200, body: body, error: nil))
        let data = try await PolkamarktURLSessionTransport().post(Data(#"{"method":"chain_getHeader"}"#.utf8), to: url("/rpc"))
        XCTAssertEqual(data, body)
        let request = try XCTUnwrap(CovDURLProtocol.recordedRequests().last)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.timeoutInterval, 15)
    }

    func testTransportRejectsHTTPFailuresAndSurfacesNetworkErrors() async throws {
        CovDURLProtocol.answer("/down", with: .init(status: 503, body: Data("busy".utf8), error: nil))
        do {
            _ = try await PolkamarktURLSessionTransport().post(Data("{}".utf8), to: url("/down"))
            XCTFail("expected an HTTP status failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, PolkamarktServiceError.invalidResponse.localizedDescription)
        }

        CovDURLProtocol.answer("/offline", with: .init(status: 0, body: nil, error: URLError(.notConnectedToInternet)))
        do {
            _ = try await PolkamarktURLSessionTransport().post(Data("{}".utf8), to: url("/offline"))
            XCTFail("expected the network error")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }

    func testRPCClientReadsTheHeaderThroughTheLiveTransport() async throws {
        let body = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": 1, "result": ["number": "0x2a"]])
        CovDURLProtocol.answer("/public-rpc", with: .init(status: 200, body: body, error: nil))
        let client = PolkamarktRPCClient(endpoint: try url("/public-rpc"), transport: PolkamarktURLSessionTransport())
        let block = try await client.currentBlock()
        XCTAssertEqual(block, "42")
    }
}

final class CovDPolkamarktListTransportTests: XCTestCase {
    private var window: UIWindow?

    override func setUp() {
        super.setUp()
        CovDURLProtocol.reset()
        URLProtocol.registerClass(CovDURLProtocol.self)
    }

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        URLProtocol.unregisterClass(CovDURLProtocol.self)
        CovDURLProtocol.reset()
        super.tearDown()
    }

    func testMarketListLoadsLiveMarketsSearchesAndOpensTheLinkedMarket() throws {
        CovDURLProtocol.rpc("chain_getHeader", result: ["number": "0x10"])
        CovDURLProtocol.rpc("rpc_methods", result: ["methods": ["chain_getHeader", "polkamarkt_quoteBuy"]])
        CovDURLProtocol.graphQL("PolkamarktLatestMarkets", response: ["data": ["markets": ["edges": [
            ["node": [
                "id": "9", "marketId": "9", "title": "Will it rain?", "category": "Weather",
                "closeBlock": "100", "probability": "0.25", "status": "Open"
            ]],
            ["node": ["id": "8", "marketId": "8", "title": "Old final", "category": "Sports", "closeBlock": "5", "status": "Resolved"]],
            ["node": ["id": "7", "marketId": "7", "title": "Snow?", "category": "Weather", "closeBlock": "200", "status": "Open"]]
        ]]]])
        let chain = CovDFixtures.soraChain(
            nodeURL: "wss://covd-transport.invalid/public-ws",
            historyURL: "https://covd-transport.invalid/graphql"
        )
        let list = PolkamarktMarketListViewController(wallet: CovDFixtures.wallet(), chain: chain, marketId: "9")
        let navigation = UINavigationController(rootViewController: list)
        window = try CovDFixtures.host(navigation)
        let table = try XCTUnwrap(CovDFixtures.findTableView(in: list.view))

        // The deep-linked market opens once its snapshot arrives.
        XCTAssertTrue(CovDFixtures.spin(timeout: 10) { navigation.viewControllers.count == 2 })
        let detail = try XCTUnwrap(navigation.topViewController as? PolkamarktMarketDetailViewController)
        XCTAssertEqual(detail.title, "Market #9")
        XCTAssertTrue(Set(CovDURLProtocol.recordedMethods()).isSuperset(of: ["chain_getHeader", "rpc_methods"]))
        navigation.popToRootViewController(animated: false)

        let open = CovDFixtures.cellTexts(table, section: 0)
        XCTAssertEqual(Set(open.compactMap(\.0)), ["Will it rain?", "Snow?"])
        XCTAssertTrue(open.contains { $0.1 == "#9 · Weather · YES 25% · KUSD" }, "\(open)")
        XCTAssertTrue(open.contains { $0.1 == "#7 · Weather · Probability unavailable · KUSD" }, "\(open)")
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 1).map(\.0), ["Old final"])

        let search = try XCTUnwrap(list.navigationItem.searchController)
        search.searchBar.text = "snow"
        list.updateSearchResults(for: search)
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 0).map(\.0), ["Snow?"])
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 1).count, 0)
        list.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(CovDFixtures.spin { navigation.viewControllers.count == 2 })
        XCTAssertEqual(navigation.topViewController?.title, "Market #7")
    }

    func testMarketListExplainsAnUnreachableIndexer() throws {
        CovDURLProtocol.answer("/graphql", with: .init(status: 500, body: Data("{}".utf8), error: nil))
        let chain = CovDFixtures.soraChain(nodeURL: nil, historyURL: "https://covd-transport.invalid/graphql")
        let list = PolkamarktMarketListViewController(wallet: CovDFixtures.wallet(), chain: chain)
        window = try CovDFixtures.host(UINavigationController(rootViewController: list))
        XCTAssertTrue(CovDFixtures.spin(timeout: 10) { list.presentedViewController is UIAlertController })
        let alert = try XCTUnwrap(list.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Polkamarkt unavailable")
        XCTAssertEqual(alert.message, PolkamarktServiceError.invalidResponse.localizedDescription)
    }
}

final class CovDLiquidityPositionLoaderTests: XCTestCase {
    func testNativeLoaderReturnsTheAccountPositionsAndRowsForSora() async throws {
        let harness = try CovDPoolHarness()
        let loader = NativeSoraLiquidityPoolPositionLoader(service: harness.service)
        let accountId = Data(repeating: 7, count: 32)
        let positions = try await loader.loadPositions(accountId: accountId)
        XCTAssertEqual(positions.map(\.poolId), harness.upstream.userPools.map(\.poolId))

        let source = SoraLiquidityPoolDeFiPositionSource(chain: harness.chain, accountId: accountId, loader: loader)
        XCTAssertEqual(source.feature, .liquidityPools)
        XCTAssertEqual(source.title, "Liquidity pools")
        let rows = try await source.loadPositions()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.feature, .liquidityPools)
        XCTAssertEqual(rows.first?.title, "XOR / VAL liquidity")

        harness.upstream.error = CovDTestError.offline
        do {
            _ = try await loader.loadPositions(accountId: accountId)
            XCTFail("expected the pool service failure")
        } catch {
            XCTAssertEqual(error as? CovDTestError, .offline)
        }
    }
}
