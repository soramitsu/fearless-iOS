import Foundation
import RobinHood
import SSFModels
import Web3
import Web3ContractABI
import XCTest
import protocol SSFRuntimeCodingService.RuntimeProviderProtocol
@testable import fearless

/// EVM balance reads when a node stops answering, through the real providers, pool and balance fetching with only the
/// HTTP transport replaced. OP Mainnet's first node in October 2026 was Blast, which answers every call with HTTP 403
/// since the service closed.
final class EthereumNodeFailoverTests: XCTestCase {
    fileprivate static let dead = "https://dead.node.test/rpc"
    fileprivate static let live = "https://live.node.test/rpc"
    fileprivate static let otherNetwork = "https://other-network.node.test/rpc"
    fileprivate static let silent = "https://silent.node.test/rpc"
    fileprivate static let reverting = "https://reverting.node.test/rpc"
    fileprivate static let token = "0x4200000000000000000000000000000000000042"
    private static let etherAsset = AssetModel(
        id: "eth", name: "Ether", symbol: "ETH", precision: 18, isUtility: true, isNative: true, ethereumType: .normal
    )
    private static let tokenAsset = AssetModel(
        id: token, name: "Optimism", symbol: "OP", precision: 18, isUtility: false, isNative: false, ethereumType: .erc20
    )
    private let accountId = Data(repeating: 0x11, count: 20)
    private let wallet = AccountGenerator.generateMetaAccount()

    override func tearDown() {
        EthereumNodeURLProtocol.clear()
        super.tearDown()
    }

    func testFailingFirstNodeMovesTheNetworkOnceAndEveryBalanceIsReadOnTheNextNode() async throws {
        let network = makeNetwork(nodes: [Self.dead, Self.live])

        async let ether = network.fetching.fetch(for: network.ether, accountId: accountId)
        async let token = network.fetching.fetch(for: network.token, accountId: accountId)
        let etherBalance = try await ether
        let tokenBalance = try await token

        XCTAssertEqual(etherBalance.1?.data.free, BigUInt(10).power(18))
        XCTAssertEqual(tokenBalance.1?.data.free, 2 * BigUInt(10).power(18))
        XCTAssertTrue(EthereumNodeURLProtocol.requests.contains { $0.url == Self.dead })
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, Self.live)

        // Both reads failed on the dead node together, and the network moved on once: the next refresh asks the
        // live node only.
        EthereumNodeURLProtocol.clearRequests()
        _ = try await network.fetching.fetch(for: network.ether, accountId: accountId)
        _ = try await network.fetching.fetch(for: network.token, accountId: accountId)
        XCTAssertFalse(EthereumNodeURLProtocol.requests.isEmpty)
        XCTAssertEqual(Set(EthereumNodeURLProtocol.requests.map(\.url)), [Self.live])
    }

    func testNodeServingAnotherNetworkIsLeftBeforeAnyBalanceIsTakenFromIt() async throws {
        let network = makeNetwork(nodes: [Self.otherNetwork, Self.live])

        let balance = try await network.fetching.fetch(for: network.ether, accountId: accountId)

        XCTAssertEqual(balance.1?.data.free, BigUInt(10).power(18))
        let askedOther = EthereumNodeURLProtocol.requests.filter { $0.url == Self.otherNetwork }.map(\.method)
        XCTAssertEqual(askedOther, ["eth_chainId"])
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, Self.live)
    }

    func testNodeTheUserChoseIsKeptWhenItFails() async throws {
        let network = makeNetwork(nodes: [Self.dead, Self.live], chosen: Self.dead)

        do {
            _ = try await network.fetching.fetch(for: network.ether, accountId: accountId)
            XCTFail("A failing chosen node must not be swapped for another node")
        } catch {
            XCTAssertTrue(EthereumNodeFailure.isNodeFailure(error), "\(error)")
        }

        let asked = Set(EthereumNodeURLProtocol.requests.map(\.url))
        XCTAssertEqual(asked, [Self.dead])
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, Self.dead)
    }

    func testRevertedCallIsTheChainsAnswerAndKeepsTheNode() async throws {
        let network = makeNetwork(nodes: [Self.reverting, Self.live])

        do {
            _ = try await network.fetching.fetch(for: network.token, accountId: accountId)
            XCTFail("A reverted call has no balance")
        } catch {
            XCTAssertFalse(EthereumNodeFailure.isNodeFailure(error), "\(error)")
        }

        XCTAssertFalse(EthereumNodeURLProtocol.requests.contains { $0.url == Self.live })
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, Self.reverting)
    }

    func testNodeThatNeverAnswersIsLeftAfterTheReadBound() async throws {
        let network = makeNetwork(nodes: [Self.silent, Self.live], readTimeout: 0.5)

        let balance = try await network.fetching.fetch(for: network.ether, accountId: accountId)

        XCTAssertEqual(balance.1?.data.free, BigUInt(10).power(18))
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, Self.live)
    }

    func testEveryNodeFailingLeavesTheBalanceFailedWithoutAnAmount() async throws {
        let network = makeNetwork(nodes: [Self.dead])

        do {
            _ = try await network.fetching.fetch(for: network.ether, accountId: accountId)
            XCTFail("No node answered, so there is no balance")
        } catch {
            XCTAssertTrue(EthereumNodeFailure.isNodeFailure(error), "\(error)")
        }
    }

    // MARK: - Batches

    func testRevertingTokenLeavesTheEtherBalanceNextToItReadAndCached() async throws {
        let chain = makeChain(nodes: [Self.reverting, Self.live])
        let batch = makeBatch([(chain, [Self.reverting, Self.live])])
        let ether = ChainAsset(chain: chain, asset: Self.etherAsset)
        let token = ChainAsset(chain: chain, asset: Self.tokenAsset)

        let balances = try await batch.fetching.fetch(for: [ether, token], wallet: wallet)

        XCTAssertEqual(balances[ether]??.data.free, BigUInt(10).power(18))
        // The token is left out rather than given no balance, and nothing is cached over its balance.
        XCTAssertFalse(balances.keys.contains(token))
        let etherKey = try storageKey(ether)
        XCTAssertEqual(try batch.cachedBalances(), [etherKey: BigUInt(10).power(18)])
        // A revert is the chain's answer, so the network stays on its node.
        XCTAssertFalse(EthereumNodeURLProtocol.requests.contains { $0.url == Self.live })
    }

    func testNetworkWithNoWorkingNodeLeavesTheOtherNetworksBalancesReadAndCached() async throws {
        let optimism = makeChain(nodes: [Self.dead])
        // The other-network node serves Ethereum (chain id 1), with 999 of each.
        let ethereum = makeChain(chainId: "1", name: "Ethereum", nodes: [Self.otherNetwork])
        let batch = makeBatch([(optimism, [Self.dead]), (ethereum, [Self.otherNetwork])])
        let assets = [optimism, ethereum].flatMap { chain in
            [Self.etherAsset, Self.tokenAsset].map { ChainAsset(chain: chain, asset: $0) }
        }

        let balances = try await batch.fetching.fetch(for: assets, wallet: wallet)

        let read = assets.filter { $0.chain.chainId == ethereum.chainId }
        let amount = 999 * BigUInt(10).power(18)
        XCTAssertEqual(Set(balances.keys), Set(read))
        read.forEach { XCTAssertEqual(balances[$0]??.data.free, amount) }
        var expected: [String: BigUInt] = [:]
        for chainAsset in read {
            let key = try storageKey(chainAsset)
            expected[key] = amount
        }
        XCTAssertEqual(try batch.cachedBalances(), expected)
        XCTAssertTrue(EthereumNodeURLProtocol.requests.contains { $0.url == Self.dead })
    }

    // MARK: - Pool

    func testFailoverMovesOncePerOutageAndComesRoundAgain() throws {
        let nodes = ["https://a.node.test", "https://b.node.test", "https://c.node.test"]
        let network = makeNetwork(nodes: nodes)
        let first = try network.pool.setupConnection(for: network.chain)
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, nodes[0])

        let second = try XCTUnwrap(network.pool.failover(for: network.chain, failed: first))
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, nodes[1])

        // Other requests that were in flight on the first node fail too. They retry on the new node and move nothing.
        let retried = try XCTUnwrap(network.pool.failover(for: network.chain, failed: first))
        XCTAssertTrue(isSameNode(retried, second))
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, nodes[1])

        let third = try XCTUnwrap(network.pool.failover(for: network.chain, failed: second))
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, nodes[2])
        _ = network.pool.failover(for: network.chain, failed: third)
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, nodes[0])
    }

    func testResetConnectionKeepsTheNodeTheNetworkMovedTo() throws {
        let network = makeNetwork(nodes: [Self.dead, Self.live])
        let first = try network.pool.setupConnection(for: network.chain)
        _ = network.pool.failover(for: network.chain, failed: first)

        network.pool.resetConnection(for: network.chain.chainId)
        XCTAssertNil(network.pool.getConnection(for: network.chain.chainId))

        _ = try network.pool.setupConnection(for: network.chain)
        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, Self.live)
    }

    func testAutomaticNodeThatCannotBeConnectedIsSkippedAndRemembered() throws {
        let unreachable = "https://unreachable.node.test"
        let reachable = "https://reachable.node.test"
        let chain = makeChain(nodes: [unreachable, reachable])
        let fetching = RefusingNodeFetching(refused: [unreachable])
        let pool = EthereumConnectionPool(
            nodeFetching: fetching,
            catalogOrder: FixedCatalogOrder([chain.chainId: [unreachable, reachable].compactMap(URL.init(string:))])
        )

        _ = try pool.setupConnection(for: chain)
        XCTAssertEqual(pool.currentNodeURL(for: chain.chainId)?.absoluteString, reachable)

        pool.resetConnection(for: chain.chainId)
        _ = try pool.setupConnection(for: chain)
        XCTAssertEqual(pool.currentNodeURL(for: chain.chainId)?.absoluteString, reachable)
        XCTAssertEqual(fetching.attempts, [unreachable, reachable, reachable])
    }

    func testFailoverAfterAResetUsesTheNetworksSettingsWithoutMoving() throws {
        let network = makeNetwork(nodes: [Self.dead, Self.live])
        let stale = try network.pool.setupConnection(for: network.chain)
        network.pool.resetConnection(for: network.chain.chainId)

        _ = network.pool.failover(for: network.chain, failed: stale)

        XCTAssertEqual(network.pool.currentNodeURL(for: network.chain.chainId)?.absoluteString, Self.dead)
    }

    // MARK: - Classification

    func testRevertedOrUndecodableCallsAreAnswersAndEverythingElseIsTheNode() throws {
        let decoder = JSONDecoder()
        let revert = try decoder.decode(RPCResponse<EthereumData>.Error.self, from: Data(#"{"code":3,"message":"execution reverted"}"#.utf8))
        let gethRevert = try decoder.decode(RPCResponse<EthereumData>.Error.self, from: Data(#"{"code":-32000,"message":"execution reverted"}"#.utf8))
        let rateLimit = try decoder.decode(RPCResponse<EthereumQuantity>.Error.self, from: Data(#"{"code":-32005,"message":"limit exceeded"}"#.utf8))
        let missingState = try decoder.decode(RPCResponse<EthereumData>.Error.self, from: Data(#"{"code":-32000,"message":"header not found"}"#.utf8))

        XCTAssertFalse(EthereumNodeFailure.isNodeFailure(revert))
        XCTAssertFalse(EthereumNodeFailure.isNodeFailure(gethRevert))
        XCTAssertFalse(EthereumNodeFailure.isNodeFailure(InvocationError.contractNotDeployed))
        XCTAssertFalse(EthereumNodeFailure.isNodeFailure(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "0x"))))

        XCTAssertTrue(EthereumNodeFailure.isNodeFailure(rateLimit))
        XCTAssertTrue(EthereumNodeFailure.isNodeFailure(missingState))
        XCTAssertTrue(EthereumNodeFailure.isNodeFailure(Web3Response<EthereumQuantity>.Error.serverError(nil)))
        XCTAssertTrue(EthereumNodeFailure.isNodeFailure(Web3Response<EthereumData>.Error.serverError(URLError(.cannotConnectToHost))))
        XCTAssertTrue(EthereumNodeFailure.isNodeFailure(Web3Response<EthereumData>.Error.decodingError(nil)))
        XCTAssertTrue(EthereumNodeFailure.isNodeFailure(Web3Response<String>.Error.emptyResponse))
        XCTAssertTrue(EthereumNodeFailure.isNodeFailure(EthereumNodeError.timeout))
        XCTAssertTrue(EthereumNodeFailure.isNodeFailure(EthereumNodeError.wrongNetwork(expected: 10, reported: 1)))
    }

    func testChainIdsAreReadInDecimalOrHexadecimal() {
        XCTAssertEqual(EthereumNodeProvider.chainId(fromCatalogId: "10"), 10)
        XCTAssertEqual(EthereumNodeProvider.chainId(fromCatalogId: "0xa"), 10)
        XCTAssertEqual(EthereumNodeProvider.chainId(fromCatalogId: "0X38"), 56)
        XCTAssertNil(EthereumNodeProvider.chainId(fromCatalogId: ""))
        XCTAssertNil(EthereumNodeProvider.chainId(fromCatalogId: "0x"))
        // A Substrate genesis hash is no EVM chain id, so such a network is not checked.
        XCTAssertNil(EthereumNodeProvider.chainId(fromCatalogId: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"))
    }

    // MARK: - Catalog order

    func testCatalogOrderIsKeptForEVMNetworksAndSurvivesARelaunch() throws {
        let suite = "EthereumNodeFailoverTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let catalog = Data(#"""
        [
          {"chainId": "10", "options": ["ethereum"], "nodes": [{"url": "https://z.node.test"}, {"url": "wss://z.node.test"}, {"url": "https://a.node.test"}]},
          {"chainId": "polkadot", "options": ["crowdloans"], "nodes": [{"url": "wss://rpc.polkadot.test"}]}
        ]
        """#.utf8)

        let order = EthereumNodeCatalogOrder(defaults: defaults)
        order.record(catalog: catalog)
        order.record(catalog: Data("not a catalog".utf8))

        let expected = ["https://z.node.test", "wss://z.node.test", "https://a.node.test"]
        XCTAssertEqual(order.nodeOrder(for: "10").map(\.absoluteString), expected)
        XCTAssertEqual(order.nodeOrder(for: "polkadot"), [])
        XCTAssertEqual(EthereumNodeCatalogOrder(defaults: defaults).nodeOrder(for: "10").map(\.absoluteString), expected)
    }

    // MARK: - Helpers

    private struct Network {
        let chain: ChainModel
        let ether: ChainAsset
        let token: ChainAsset
        let pool: EthereumConnectionPool
        let fetching: EthereumRemoteBalanceFetching
    }

    private func makeChain(
        chainId: ChainModel.Id = "10",
        name: String = "OP Mainnet",
        nodes: [String],
        chosen: String? = nil
    ) -> ChainModel {
        let nodeModels = nodes.compactMap { URL(string: $0) }.map { ChainNodeModel(url: $0, name: $0.absoluteString, apikey: nil) }
        return ChainModel(
            rank: 1,
            disabled: false,
            chainId: chainId,
            paraId: nil,
            name: name,
            assets: [Self.etherAsset, Self.tokenAsset],
            xcm: nil,
            nodes: Set(nodeModels),
            addressPrefix: 0,
            icon: nil,
            options: [.ethereum],
            selectedNode: nodeModels.first { $0.url.absoluteString == chosen },
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeNetwork(nodes: [String], chosen: String? = nil, readTimeout: TimeInterval = 5) -> Network {
        let chain = makeChain(nodes: nodes, chosen: chosen)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EthereumNodeURLProtocol.self]
        let pool = EthereumConnectionPool(
            nodeFetching: EthereumNodeFetching(session: URLSession(configuration: configuration)),
            catalogOrder: FixedCatalogOrder([chain.chainId: nodes.compactMap(URL.init(string:))])
        )
        let registry = PoolChainRegistry(chains: [chain], pool: pool)
        let fetching = EthereumRemoteBalanceFetching(
            chainRegistry: registry,
            repositoryWrapper: BalanceRepositoryCacheWrapper(
                logger: Logger.shared,
                repository: AnyDataProviderRepository(RecordingRepository<AccountInfoStorageWrapper>()),
                operationManager: OperationManager()
            ),
            nodeReadTimeout: readTimeout
        )

        return Network(
            chain: chain,
            ether: ChainAsset(chain: chain, asset: Self.etherAsset),
            token: ChainAsset(chain: chain, asset: Self.tokenAsset),
            pool: pool,
            fetching: fetching
        )
    }

    private struct Batch {
        let fetching: EthereumRemoteBalanceFetching
        let cache: RecordingRepository<AccountInfoStorageWrapper>
        let cacheQueue: OperationQueue

        /// The free balances cached, by storage key, once every cache write has finished.
        func cachedBalances() throws -> [String: BigUInt] {
            cacheQueue.waitUntilAllOperationsAreFinished()
            return try cache.saved.mapValues { try JSONDecoder().decode(AccountInfo.self, from: $0.data).data.free }
        }
    }

    /// EVM networks that share a pool and a balance cache, each with its nodes in catalog order.
    private func makeBatch(_ networks: [(chain: ChainModel, nodes: [String])]) -> Batch {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EthereumNodeURLProtocol.self]
        let order = Dictionary(uniqueKeysWithValues: networks.map { ($0.chain.chainId, $0.nodes.compactMap(URL.init(string:))) })
        let pool = EthereumConnectionPool(
            nodeFetching: EthereumNodeFetching(session: URLSession(configuration: configuration)),
            catalogOrder: FixedCatalogOrder(order)
        )
        let cache = RecordingRepository<AccountInfoStorageWrapper>()
        let cacheQueue = OperationQueue()
        let fetching = EthereumRemoteBalanceFetching(
            chainRegistry: PoolChainRegistry(chains: networks.map { $0.chain }, pool: pool),
            repositoryWrapper: BalanceRepositoryCacheWrapper(
                logger: Logger.shared,
                repository: AnyDataProviderRepository(cache),
                operationManager: OperationManager(operationQueue: cacheQueue)
            ),
            nodeReadTimeout: 5
        )

        return Batch(fetching: fetching, cache: cache, cacheQueue: cacheQueue)
    }

    /// Where the balance fetching caches this wallet's balance of `chainAsset`.
    private func storageKey(_ chainAsset: ChainAsset) throws -> String {
        let accountId = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId)
        return try LocalStorageKeyFactory().createFromStoragePath(
            chainAsset.storagePath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        )
    }

    private func isSameNode(_ lhs: Web3.Eth, _ rhs: Web3.Eth) -> Bool {
        (lhs.properties.provider as? EthereumNodeProvider) === (rhs.properties.provider as? EthereumNodeProvider)
    }
}

/// JSON-RPC nodes by URL: the dead one answers HTTP 403, the live one serves OP Mainnet (chain id 10) with 1 ETH and
/// 2 OP, the other-network one serves Ethereum (chain id 1) with 999 of each, the silent one never answers, and the
/// reverting one serves OP Mainnet but reverts every call.
private final class EthereumNodeURLProtocol: URLProtocol {
    struct Request: Equatable {
        let url: String
        let method: String
    }

    private static let lock = NSLock()
    private static var recorded: [Request] = []

    static var requests: [Request] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static func clearRequests() {
        lock.lock()
        defer { lock.unlock() }
        recorded = []
    }

    static func clear() {
        clearRequests()
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let bodyData = request.httpBody ?? Self.readAll(request.httpBodyStream)
        let body = bodyData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let url = request.url?.absoluteString ?? ""
        let method = body["method"] as? String ?? ""
        let id = body["id"] as? Int ?? 0

        Self.lock.lock()
        Self.recorded.append(Request(url: url, method: method))
        Self.lock.unlock()

        guard let answer = Self.answer(url: url, method: method, id: id) else {
            return
        }
        guard
            let requestURL = request.url,
            let response = HTTPURLResponse(url: requestURL, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(answer.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func answer(url: String, method: String, id: Int) -> (status: Int, body: String)? {
        let result = { (value: String) in (200, #"{"jsonrpc":"2.0","id":\#(id),"result":"\#(value)"}"#) }
        let ether = BigUInt(10).power(18)

        switch url {
        case EthereumNodeFailoverTests.dead:
            return (403, "Blast API is no longer available")
        case EthereumNodeFailoverTests.silent:
            return nil
        case EthereumNodeFailoverTests.otherNetwork:
            switch method {
            case "eth_chainId": return result("0x1")
            case "eth_getBalance": return result(quantity(999 * ether))
            default: return result(word(999 * ether))
            }
        case EthereumNodeFailoverTests.reverting:
            switch method {
            case "eth_chainId": return result("0xa")
            case "eth_call": return (200, #"{"jsonrpc":"2.0","id":\#(id),"error":{"code":3,"message":"execution reverted"}}"#)
            default: return result(quantity(ether))
            }
        default:
            switch method {
            case "eth_chainId": return result("0xa")
            case "eth_getBalance": return result(quantity(ether))
            default: return result(word(2 * ether))
            }
        }
    }

    private static func quantity(_ value: BigUInt) -> String {
        "0x" + String(value, radix: 16)
    }

    /// An ABI-encoded `uint256`, as `balanceOf` returns it.
    private static func word(_ value: BigUInt) -> String {
        let digits = String(value, radix: 16)
        return "0x" + String(repeating: "0", count: 64 - digits.count) + digits
    }

    private static func readAll(_ stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class FixedCatalogOrder: EthereumNodeCatalogOrderProtocol {
    private let order: [ChainModel.Id: [URL]]

    init(_ order: [ChainModel.Id: [URL]]) {
        self.order = order
    }

    func nodeOrder(for chainId: ChainModel.Id) -> [URL] {
        order[chainId] ?? []
    }

    func record(catalog _: Data) {}
}

/// The registry's EVM part for some networks: connections come from the pool, as `ChainRegistry` hands them out.
private final class PoolChainRegistry: ChainRegistryProtocol {
    let chains: [ChainModel]
    let pool: EthereumConnectionPool

    init(chains: [ChainModel], pool: EthereumConnectionPool) {
        self.chains = chains
        self.pool = pool
    }

    var availableChainIds: Set<ChainModel.Id>? { Set(chains.map(\.chainId)) }
    var availableChains: [ChainModel] { chains }
    var chainsTypesMap: [String: Data] { [:] }

    func resetConnection(for chainId: ChainModel.Id) {
        pool.resetConnection(for: chainId)
    }

    func retryConnection(for _: ChainModel.Id) {}

    func getConnection(for _: ChainModel.Id) -> ChainConnection? { nil }

    func getEthereumConnection(for chainId: ChainModel.Id) -> Web3.Eth? {
        getChain(for: chainId).flatMap { try? pool.setupConnection(for: $0) }
    }

    func failoverEthereumConnection(for chainId: ChainModel.Id, failed: Web3.Eth) -> Web3.Eth? {
        getChain(for: chainId).flatMap { pool.failover(for: $0, failed: failed) }
    }

    func getTonApiClientFactory() throws -> TonAPIClientFactory {
        throw ChainRegistryError.connectionUnavailable
    }

    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { nil }

    func getChain(for chainId: ChainModel.Id) -> ChainModel? {
        chains.first { $0.chainId == chainId }
    }

    func chainsSubscribe(
        _: AnyObject,
        runningInQueue _: DispatchQueue,
        updateClosure _: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {}

    func chainsUnsubscribe(_: AnyObject) {}
    func syncUp() {}
    func performHotBoot() {}
    func performColdBoot() {}
    func subscribeToChains() {}
}

/// Stores nothing it can be asked for, and keeps what is saved to it, by identifier, for the test to read.
private final class RecordingRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    typealias Model = T

    private let lock = NSLock()
    private var recorded: [String: T] = [:]

    var saved: [String: T] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<T?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        ClosureOperation { [] }
    }

    func saveOperation(_ updates: @escaping () throws -> [T], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation<Void> { [weak self] in
            let models = try updates()
            self?.record(models)
        }
    }

    func saveBatchOperation(_ updates: @escaping () throws -> [T], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation<Void> { [weak self] in
            let models = try updates()
            self?.record(models)
        }
    }

    private func record(_ models: [T]) {
        lock.lock()
        models.forEach { recorded[$0.identifier] = $0 }
        lock.unlock()
    }

    func replaceOperation(_: @escaping () throws -> [T]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { 0 }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}

/// Connects every node without contacting it, except the refused ones, which fail to connect as an unreachable
/// WebSocket node does.
private final class RefusingNodeFetching: EthereumNodeFetchingProtocol {
    private let refused: Set<String>
    private let lock = NSLock()
    private var tried: [String] = []

    init(refused: Set<String>) {
        self.refused = refused
    }

    var attempts: [String] {
        lock.lock()
        defer { lock.unlock() }
        return tried
    }

    func getNode(for chain: ChainModel, url: URL) throws -> Web3.Eth {
        lock.lock()
        tried.append(url.absoluteString)
        lock.unlock()

        if refused.contains(url.absoluteString) {
            throw URLError(.cannotConnectToHost)
        }
        return try EthereumNodeFetching().getNode(for: chain, url: url)
    }
}
