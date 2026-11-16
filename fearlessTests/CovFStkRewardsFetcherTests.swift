import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

struct CovFStkCapturedRequest {
    let url: URL
    let method: String?
    let contentType: String?
    let body: Data?
}

/// Answers requests to the `.invalid` rewards host for `URLSession.shared`, which the fetchers use.
final class CovFStkRewardsURLProtocol: URLProtocol {
    static let host = "rewards.covfstk.invalid"
    private static let lock = NSLock()
    private static var replyStatus = 200
    private static var replyBody = Data()
    private static var captured: [CovFStkCapturedRequest] = []

    static var requests: [CovFStkCapturedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return captured
    }

    static func stub(status: Int = 200, json: Any) throws {
        let body = try JSONSerialization.data(withJSONObject: json)
        lock.lock()
        replyStatus = status
        replyBody = body
        captured = []
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        replyStatus = 200
        replyBody = Data()
        captured = []
        lock.unlock()
    }

    private static func readBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let captured = CovFStkCapturedRequest(
            url: url,
            method: request.httpMethod,
            contentType: request.value(forHTTPHeaderField: "Content-Type"),
            body: Self.readBody(of: request)
        )
        Self.lock.lock()
        Self.captured.append(captured)
        let status = Self.replyStatus
        let body = Self.replyBody
        Self.lock.unlock()

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class CovFStkRewardsFetcherTests: XCTestCase {
    private static let url = URL(string: "https://rewards.covfstk.invalid/graphql")

    override func setUp() {
        super.setUp()
        CovFStkRewardsURLProtocol.reset()
        URLProtocol.registerClass(CovFStkRewardsURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(CovFStkRewardsURLProtocol.self)
        CovFStkRewardsURLProtocol.reset()
        super.tearDown()
    }

    private func chain(type: String?, name: String = "CovFStk") throws -> ChainModel {
        let url = try XCTUnwrap(Self.url)
        let explorer = try type.map { try XCTUnwrap(ChainModel.BlockExplorer(type: $0, url: url)) }
        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "covfstk-rewards",
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            icon: nil,
            externalApi: explorer.map { ChainModel.ExternalApiSet(staking: $0) },
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func assertPostedQuery(_ query: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let request = try XCTUnwrap(CovFStkRewardsURLProtocol.requests.last, file: file, line: line)
        XCTAssertEqual(CovFStkRewardsURLProtocol.requests.count, 1, file: file, line: line)
        XCTAssertEqual(request.url, Self.url, file: file, line: line)
        XCTAssertEqual(request.method?.uppercased(), "POST", file: file, line: line)
        XCTAssertEqual(request.contentType, "application/json", file: file, line: line)
        let body = try XCTUnwrap(request.body, file: file, line: line)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String], file: file, line: line)
        XCTAssertEqual(json, ["query": query], file: file, line: line)
    }

    // MARK: Request

    func testRewardsRequestPostsTheQueryAsJsonToTheBaseUrl() throws {
        let url = try XCTUnwrap(Self.url)

        let request = try StakingRewardsRequest(baseURL: url, query: "{ rewards }")

        XCTAssertEqual(request.baseURL, url)
        XCTAssertEqual(request.method, .post)
        XCTAssertNil(request.endpoint)
        XCTAssertNil(request.queryItems)
        XCTAssertEqual(request.headers.map(\.field), ["Content-Type"])
        XCTAssertEqual(request.headers.map(\.value), ["application/json"])
        let body = try XCTUnwrap(request.body)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: String], ["query": "{ rewards }"])
    }

    // MARK: Assembly

    func testAssemblyPicksTheFetcherForTheStakingExplorer() throws {
        let assembly = StakingRewardsFetcherAssembly()

        XCTAssertTrue(try assembly.fetcher(for: chain(type: "subquery")) is SubqueryStakingRewardsFetcher)
        XCTAssertTrue(try assembly.fetcher(for: chain(type: "subsquid")) is SubsquidStakingRewardsFetcher)
        XCTAssertTrue(try assembly.fetcher(for: chain(type: "giantsquid")) is GiantsquidStakingRewardsFetcher)
        XCTAssertTrue(try assembly.fetcher(for: chain(type: "sora")) is SoraStakingRewardsFetcher)
        XCTAssertTrue(try assembly.fetcher(for: chain(type: nil)) is SubsquidStakingRewardsFetcher)
        XCTAssertThrowsError(try assembly.fetcher(for: chain(type: "alchemy", name: "Alchemy chain"))) { error in
            guard case let .missingBlockExplorer(name)? = error as? StakingRewardsFetcherError else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(name, "Alchemy chain")
        }
    }

    // MARK: Query strings

    func testSubsquidQueryFiltersByAddressAndFormatsTheTimestampWindow() throws {
        let fetcher = try SubsquidStakingRewardsFetcher(chain: chain(type: "subsquid"))

        let open = fetcher.queryString(address: "ADDR", startTimestamp: nil, endTimestamp: nil)
        let window = fetcher.queryString(address: "ADDR", startTimestamp: 0, endTimestamp: 86400)
        let since = fetcher.queryString(address: "ADDR", startTimestamp: 86400, endTimestamp: nil)
        let until = fetcher.queryString(address: "ADDR", startTimestamp: nil, endTimestamp: 0)

        XCTAssertTrue(open.contains("historyElements(orderBy: timestamp_DESC, where: {address_eq: \"ADDR\""))
        XCTAssertTrue(open.contains("reward_isNull: false"))
        XCTAssertFalse(open.contains("AND:"))
        XCTAssertTrue(window.contains("AND: {timestamp_gte:\"1970-01-01T00:00:00.000000Z\"timestamp_lte:\"1970-01-02T00:00:00.000000Z\"}"))
        XCTAssertTrue(since.contains("AND: {timestamp_gte:\"1970-01-02T00:00:00.000000Z\"}"))
        XCTAssertTrue(until.contains("AND: {timestamp_lte:\"1970-01-01T00:00:00.000000Z\"}"))
    }

    func testGiantsquidQueryFiltersByPublicKeyAndTimestampWindow() throws {
        let fetcher = try GiantsquidStakingRewardsFetcher(chain: chain(type: "giantsquid"))

        let open = fetcher.queryString(address: "ADDR", startTimestamp: nil, endTimestamp: nil)
        let window = fetcher.queryString(address: "ADDR", startTimestamp: 0, endTimestamp: 86400)
        let since = fetcher.queryString(address: "ADDR", startTimestamp: 0, endTimestamp: nil)
        let until = fetcher.queryString(address: "ADDR", startTimestamp: nil, endTimestamp: 86400)

        XCTAssertTrue(open.contains("stakingRewards(orderBy: timestamp_DESC, where: {account: {publicKey_eq: \"ADDR\"}"))
        XCTAssertFalse(open.contains("AND:"))
        XCTAssertTrue(window.contains("AND: {timestamp_gte:\"1970-01-01T00:00:00.000000Z\"timestamp_lte:\"1970-01-02T00:00:00.000000Z\"}"))
        XCTAssertTrue(since.contains("AND: {timestamp_gte:\"1970-01-01T00:00:00.000000Z\"}"))
        XCTAssertTrue(until.contains("AND: {timestamp_lte:\"1970-01-02T00:00:00.000000Z\"}"))
    }

    func testSoraQueryFiltersByPayeeAndTimestampWindow() throws {
        let fetcher = try SoraStakingRewardsFetcher(chain: chain(type: "sora"))

        let open = fetcher.queryString(address: "ADDR", startTimestamp: nil, endTimestamp: nil)
        let window = fetcher.queryString(address: "ADDR", startTimestamp: 0, endTimestamp: 86400)
        let since = fetcher.queryString(address: "ADDR", startTimestamp: 86400, endTimestamp: nil)
        let until = fetcher.queryString(address: "ADDR", startTimestamp: nil, endTimestamp: 0)

        XCTAssertTrue(open.contains("stakingRewards(orderBy: timestamp_DESC, where: {payee_eq: \"ADDR\""))
        XCTAssertFalse(open.contains("AND:"))
        XCTAssertTrue(window.contains("AND: {timestamp_gte:\"1970-01-01T00:00:00.000000Z\"timestamp_lte:\"1970-01-02T00:00:00.000000Z\"}"))
        XCTAssertTrue(since.contains("AND: {timestamp_gte:\"1970-01-02T00:00:00.000000Z\"}"))
        XCTAssertTrue(until.contains("AND: {timestamp_lte:\"1970-01-01T00:00:00.000000Z\"}"))
    }

    func testSubqueryQueryFiltersByAddressAndRawTimestampBounds() throws {
        let fetcher = try SubqueryStakingRewardsFetcher(chain: chain(type: "subquery"))

        let open = fetcher.queryString(address: "ADDR", startTimestamp: nil, endTimestamp: nil)
        let window = fetcher.queryString(address: "ADDR", startTimestamp: 10, endTimestamp: 20)
        let since = fetcher.queryString(address: "ADDR", startTimestamp: 10, endTimestamp: nil)
        let until = fetcher.queryString(address: "ADDR", startTimestamp: nil, endTimestamp: 20)

        XCTAssertTrue(open.contains("address: { equalTo: \"ADDR\"}"))
        XCTAssertTrue(open.contains("reward: { isNull: false }"))
        XCTAssertFalse(open.contains("timestamp:{"))
        XCTAssertTrue(window.contains("timestamp:{greaterThanOrEqualTo:\"10\",lessThanOrEqualTo:\"20\",}"))
        XCTAssertTrue(since.contains("timestamp:{greaterThanOrEqualTo:\"10\",}"))
        XCTAssertTrue(until.contains("timestamp:{lessThanOrEqualTo:\"20\",}"))
    }

    // MARK: Fetching

    func testFetchersWithoutStakingExplorerThrowMissingBlockExplorer() async throws {
        let explorerless = try chain(type: nil, name: "No explorer")
        let fetchers: [StakingRewardsFetcher] = [
            SubqueryStakingRewardsFetcher(chain: explorerless),
            SubsquidStakingRewardsFetcher(chain: explorerless),
            GiantsquidStakingRewardsFetcher(chain: explorerless),
            SoraStakingRewardsFetcher(chain: explorerless)
        ]

        for fetcher in fetchers {
            do {
                _ = try await fetcher.fetchAllRewards(address: "ADDR", startTimestamp: nil, endTimestamp: nil)
                XCTFail("\(type(of: fetcher)) fetched without an explorer")
            } catch {
                guard case let .missingBlockExplorer(name)? = error as? StakingRewardsFetcherError else {
                    XCTFail("Unexpected error \(error)")
                    continue
                }
                XCTAssertEqual(name, "No explorer")
            }
        }
        XCTAssertTrue(CovFStkRewardsURLProtocol.requests.isEmpty)
    }

    func testSubsquidFetcherPostsItsQueryAndReturnsHistoryElements() async throws {
        try CovFStkRewardsURLProtocol.stub(json: ["data": ["historyElements": [[
            "id": "reward-1",
            "timestamp": 1_700_000_000,
            "address": "ADDR",
            "success": true,
            "reward": ["amount": "5", "era": 7, "stash": "STASH", "validator": "VALIDATOR"]
        ]]]])
        let fetcher = try SubsquidStakingRewardsFetcher(chain: chain(type: "subsquid"))

        let rewards = try await fetcher.fetchAllRewards(address: "ADDR", startTimestamp: 0, endTimestamp: 86400)

        XCTAssertEqual(rewards.map { $0.identifier }, ["reward-1"])
        XCTAssertEqual(rewards.first?.address, "ADDR")
        XCTAssertEqual(rewards.first?.rewardInfo?.amount, "5")
        XCTAssertEqual(rewards.first?.rewardInfo?.era, 7)
        XCTAssertEqual(rewards.first?.rewardInfo?.validator, "VALIDATOR")
        try assertPostedQuery(fetcher.queryString(address: "ADDR", startTimestamp: 0, endTimestamp: 86400))
    }

    func testGiantsquidFetcherPostsItsQueryAndReturnsStakingRewards() async throws {
        try CovFStkRewardsURLProtocol.stub(json: ["data": ["stakingRewards": [[
            "id": "reward-2",
            "amount": "9",
            "era": 3,
            "accountId": "ACCOUNT",
            "timestamp": "2023-11-14T22:13:20.000000Z",
            "blockNumber": 10
        ]]]])
        let fetcher = try GiantsquidStakingRewardsFetcher(chain: chain(type: "giantsquid"))

        let rewards = try await fetcher.fetchAllRewards(address: "ADDR", startTimestamp: nil, endTimestamp: nil)

        XCTAssertEqual(rewards.map { $0.identifier }, ["reward-2"])
        XCTAssertEqual(rewards.first?.address, "ACCOUNT")
        XCTAssertEqual(rewards.first?.rewardInfo?.amount, "9")
        XCTAssertEqual(rewards.first?.rewardInfo?.era, 3)
        try assertPostedQuery(fetcher.queryString(address: "ADDR", startTimestamp: nil, endTimestamp: nil))
    }

    func testSoraFetcherPostsItsQueryAndReturnsStakingRewards() async throws {
        try CovFStkRewardsURLProtocol.stub(json: ["data": ["stakingRewards": [
            ["id": "reward-3", "amount": "11", "timestamp": "2023-11-14T22:13:20.000000Z"],
            ["id": "reward-4", "amount": "12", "timestamp": 1_700_000_000]
        ]]])
        let fetcher = try SoraStakingRewardsFetcher(chain: chain(type: "sora"))

        let rewards = try await fetcher.fetchAllRewards(address: "ADDR", startTimestamp: 86400, endTimestamp: nil)

        XCTAssertEqual(rewards.map { $0.identifier }, ["reward-3", "reward-4"])
        XCTAssertEqual(rewards.map { $0.rewardInfo?.amount }, ["11", "12"])
        XCTAssertEqual(rewards.last?.timestamp, "1700000000")
        try assertPostedQuery(fetcher.queryString(address: "ADDR", startTimestamp: 86400, endTimestamp: nil))
    }

    func testSubqueryFetcherPostsItsQueryAndReturnsHistoryNodes() async throws {
        try CovFStkRewardsURLProtocol.stub(json: ["data": ["historyElements": ["nodes": [[
            "id": "reward-5",
            "timestamp": "1700000000",
            "address": "ADDR",
            "reward": ["amount": "13", "isReward": false, "era": 4, "validator": "VALIDATOR"]
        ]]]]])
        let fetcher = try SubqueryStakingRewardsFetcher(chain: chain(type: "subquery"))

        let rewards = try await fetcher.fetchAllRewards(address: "ADDR", startTimestamp: 10, endTimestamp: 20)

        XCTAssertEqual(rewards.map { $0.identifier }, ["reward-5"])
        XCTAssertEqual(rewards.first?.timestamp, "1700000000")
        XCTAssertEqual(rewards.first?.rewardInfo?.amount, "13")
        XCTAssertEqual(rewards.first?.rewardInfo?.isReward, false)
        XCTAssertEqual(rewards.first?.rewardInfo?.era, 4)
        try assertPostedQuery(fetcher.queryString(address: "ADDR", startTimestamp: 10, endTimestamp: 20))
    }

    func testFetchersThrowTheFirstGraphQLError() async throws {
        let fetchers: [StakingRewardsFetcher] = try [
            SubqueryStakingRewardsFetcher(chain: chain(type: "subquery")),
            SubsquidStakingRewardsFetcher(chain: chain(type: "subsquid")),
            GiantsquidStakingRewardsFetcher(chain: chain(type: "giantsquid")),
            SoraStakingRewardsFetcher(chain: chain(type: "sora"))
        ]

        for fetcher in fetchers {
            try CovFStkRewardsURLProtocol.stub(json: ["errors": [["message": "indexer down"], ["message": "second"]]])
            do {
                _ = try await fetcher.fetchAllRewards(address: "ADDR", startTimestamp: nil, endTimestamp: nil)
                XCTFail("\(type(of: fetcher)) ignored the GraphQL error")
            } catch {
                XCTAssertEqual((error as? GraphQLError)?.message, "indexer down")
            }
            XCTAssertEqual(CovFStkRewardsURLProtocol.requests.count, 1)
        }
    }
}
