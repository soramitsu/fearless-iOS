import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import XCTest
@testable import fearless

final class CovGHistoryFactoryTests: XCTestCase {
    private let filters: [WalletTransactionHistoryFilter] = [
        .init(type: .transfer, selected: true), .init(type: .reward, selected: true), .init(type: .other, selected: true)
    ]
    private let owner = "owner"

    func testSubsquidMapsAndSortsRemoteTransfersAndAdvancesOffset() throws {
        let repository = InMemoryDataProviderRepository<TransactionHistoryItem>()
        let factory = SubsquidHistoryOperationFactory(txStorage: AnyDataProviderRepository(repository))
        for cursor in [nil, "10", "invalid"] as [String?] {
            let wrapper = try history(factory, context: cursor.map { ["endCursor": $0] })
            let network = try CovGOperationFixtures.network(wrapper, as: SubsquidHistoryResponse.self)
            let query = try CovGOperationFixtures.query(network)
            XCTAssertTrue(query.contains("address_eq: \"owner\""))
            XCTAssertTrue(query.contains("limit: 2"))
            XCTAssertTrue(query.contains("offset: \(Int(cursor ?? "0") ?? 0)"))
            XCTAssertFalse(query.contains("transfer_isNull"))
            checkGraphQLErrors(network)
            try CovGOperationFixtures.respond(network, json: "{\"data\":{\"historyElements\":[\(element("old", time: "1000")),\(element("new", time: "2000"))]}}")
            let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertEqual(page.transactions.map(\.transactionId), ["new", "old"])
            XCTAssertEqual(page.transactions.map(\.amount.stringValue), ["1", "1"])
            XCTAssertEqual(page.context?["endCursor"], String((Int(cursor ?? "0") ?? 0) + 2))
        }
    }

    func testArrowsquidMapsAndSortsRemoteTransfersAndAdvancesOffset() throws {
        let repository = InMemoryDataProviderRepository<TransactionHistoryItem>()
        let factory = ArrowsquidHistoryOperationFactory(txStorage: AnyDataProviderRepository(repository))
        let wrapper = try history(factory, context: ["endCursor": "7"])
        let network = try CovGOperationFixtures.network(wrapper, as: ArrowsquidHistoryResponse.self)
        let query = try CovGOperationFixtures.query(network)
        XCTAssertTrue(query.contains("offset: 7"))
        XCTAssertTrue(query.contains("limit: 2"))
        XCTAssertFalse(query.contains("reward_isNull"))
        checkGraphQLErrors(network)
        let nodes = #"""
        {"id":"old",
        "timestamp":1,
        "address":"owner",
        "success":true,
        "transfer":{"amount":"1000000000000",
        "from":"owner",
        "to":"peer"}},
         {"id":"new",
        "timestamp":2,
        "address":"owner",
        "success":false,
        "transfer":{"amount":"2000000000000",
        "from":"peer",
        "to":"owner"}}
        """#
        try CovGOperationFixtures.respond(network, json: "{\"data\":{\"historyElements\":[\(nodes)]}}")
        let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(page.transactions.map(\.transactionId), ["new", "old"])
        XCTAssertEqual(page.context?["endCursor"], "9")
        XCTAssertEqual(page.transactions.first?.amount.stringValue, "2")
    }

    func testGiantsquidMapsTransferAndDoesNotOfferAnotherPage() throws {
        let repository = InMemoryDataProviderRepository<TransactionHistoryItem>()
        let factory = GiantsquidHistoryOperationFactory(txStorage: AnyDataProviderRepository(repository))
        let wrapper = try history(factory)
        let network = try CovGOperationFixtures.network(wrapper, as: GiantsquidResponseData.self)
        let query = try CovGOperationFixtures.query(network)
        XCTAssertTrue(query.contains("id_eq: \"owner\""))
        XCTAssertTrue(query.contains("transfers("))
        XCTAssertFalse(query.contains("rewards("))
        XCTAssertFalse(query.contains("slashes("))
        checkGraphQLErrors(network)
        let node = #"""
        {"id":"response",
        "transfer":{"id":"transfer",
        "amount":"3000000000000",
        "from":{"id":"owner"},
        "to":{"id":"peer"},
        "success":true,
        "timestamp":"2024-01-01T00:00:00.000Z",
        "extrinsicHash":"hash"}}
        """#
        try CovGOperationFixtures.respond(network, json: "{\"data\":{\"transfers\":[\(node)]}}")
        let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(page.transactions.count, 1)
        XCTAssertEqual(page.transactions.first?.amount.stringValue, "3")
        XCTAssertNil(page.context)
    }

    func testFactoriesReturnEmptyCompletePageWhenAllSourcesAreExcluded() throws {
        for factory in factories() {
            let wrapper = try history(factory, filters: [])
            XCTAssertEqual(wrapper.allOperations.count, 1)
            let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertTrue(page.transactions.isEmpty)
            XCTAssertNil(page.context)
        }
    }

    func testMissingExplorerReturnsEmptyHistoryWithoutNetwork() throws {
        for factory in factories() {
            let wrapper = try history(factory, chain: CovGOperationFixtures.chain(history: nil))
            let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertTrue(page.transactions.isEmpty)
        }
    }

    func testDeselectedSourcesAppearInQueries() throws {
        let repository = AnyDataProviderRepository(InMemoryDataProviderRepository<TransactionHistoryItem>())
        let excluded: [WalletTransactionHistoryFilter] = [
            .init(type: .transfer, selected: false), .init(type: .reward, selected: false), .init(type: .other, selected: false)
        ]
        let subsquid = try history(SubsquidHistoryOperationFactory(txStorage: repository), filters: excluded)
        let sqNetwork = try CovGOperationFixtures.network(subsquid, as: SubsquidHistoryResponse.self)
        let sqQuery = try CovGOperationFixtures.query(sqNetwork)
        for field in ["transfer", "reward", "extrinsic"] {
            XCTAssertTrue(sqQuery.contains("\(field)_isNull: true"))
        }
        let arrow = try history(ArrowsquidHistoryOperationFactory(txStorage: repository), filters: excluded)
        let arrowQuery = try CovGOperationFixtures.query(CovGOperationFixtures.network(arrow, as: ArrowsquidHistoryResponse.self))
        XCTAssertTrue(arrowQuery.contains("transfer_isNull: true"))
        XCTAssertTrue(arrowQuery.contains("reward_isNull: true"))
        let giant = try history(GiantsquidHistoryOperationFactory(txStorage: repository), filters: excluded)
        let giantQuery = try CovGOperationFixtures.query(CovGOperationFixtures.network(giant, as: GiantsquidResponseData.self))
        XCTAssertFalse(giantQuery.contains("transfers("))
    }

    func testFirstPageMergesPendingLocalTransactions() throws {
        let repository = InMemoryDataProviderRepository<TransactionHistoryItem>()
        let pending = TransactionHistoryItem(
            sender: owner, receiver: "peer", status: .pending, txHash: "pending-hash", timestamp: 9,
            fee: "0", blockNumber: nil, txIndex: nil, callPath: .transfer, call: nil
        )
        try CovGOperationFixtures.run(repository.saveOperation({ [pending] }, { [] }))
        for factory in factories(repository: repository) {
            let wrapper = try history(factory, chain: CovGOperationFixtures.chain(history: nil))
            let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertEqual(page.transactions.map(\.transactionId), ["pending-hash"])
            XCTAssertEqual(try CovGOperationFixtures.run(repository.fetchCountOperation()), 1)
        }
    }

    func testSubqueryFiltersTokenHistoryAndCarriesProviderCursors() throws {
        let registry = CovGHistoryRegistry()
        let repository = AnyDataProviderRepository(InMemoryDataProviderRepository<TransactionHistoryItem>())
        let factory = SubqueryHistoryOperationFactory(txStorage: repository, chainRegistry: registry)
        let wrapper = try history(factory, context: ["endCursor": "before"])
        let network = try CovGOperationFixtures.network(wrapper, as: SubqueryHistoryData.self)
        let query = try CovGOperationFixtures.query(network)
        XCTAssertTrue(query.contains("after: \"before\""))
        XCTAssertTrue(query.contains("first: 2"))
        checkGraphQLErrors(network)
        let nodes = "\(element("native", time: "1")),\(element("token", time: "2", assetId: "0x01"))"
        try CovGOperationFixtures.respond(network, json: "{\"data\":{\"historyElements\":{\"nodes\":[\(nodes)],\"pageInfo\":{\"startCursor\":\"start\",\"endCursor\":\"end\"}}}}")
        let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(page.transactions.map(\.transactionId), ["native"])
        XCTAssertEqual(page.context?["startCursor"], "start")
        XCTAssertEqual(page.context?["endCursor"], "end")
    }

    func testSoraFiltersByAssetAndStakingRules() throws {
        let registry = CovGHistoryRegistry()
        let repository = AnyDataProviderRepository(InMemoryDataProviderRepository<TransactionHistoryItem>())
        let factory = SoraSubsquidHistoryOperationFactory(txStorage: repository, chainRegistry: registry)
        for symbol in ["UNIT", "VAL"] {
            let asset = AssetModel(id: "asset", name: symbol, symbol: symbol, precision: 12, currencyId: "asset", isUtility: true, isNative: true)
            let wrapper = try factory.fetchTransactionHistoryOperation(
                asset: asset, chain: CovGOperationFixtures.chain(), address: owner,
                filters: filters + [.init(type: .swap, selected: true)], pagination: Pagination(count: 9)
            )
            let network = try CovGOperationFixtures.network(wrapper, as: SoraSubsquidHistoryConnectionResponse.self)
            let query = try CovGOperationFixtures.query(network)
            XCTAssertTrue(query.contains("after: \"1\""))
            XCTAssertFalse(query.contains("method_not_in"))
            checkGraphQLErrors(network)
            let nodes = [
                #"{"id":"staking","module":"staking","method":"bond"}"#,
                #"{"id":"reward","module":"staking","method":"rewarded"}"#,
                #"{"id":"target","data":{"targetAssetId":"asset"}}"#,
                #"{"id":"base","data":{"baseAssetId":"asset"}}"#,
                #"{"id":"asset","data":{"assetId":"asset"}}"#,
                #"{"id":"unrelated","data":{"assetId":"other"}}"#
            ].map { "{\"node\":\($0)}" }.joined(separator: ",")
            try CovGOperationFixtures.respond(
                network,
                json: "{\"data\":{\"historyElementsConnection\":{\"edges\":[\(nodes)],\"totalCount\":6,\"pageInfo\":{\"startCursor\":\"s\",\"endCursor\":\"e\"}}}}"
            )
            let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            let expected = symbol == "VAL" ? ["staking", "reward", "target", "base", "asset"] : ["staking", "target", "base", "asset"]
            XCTAssertEqual(page.transactions.map(\.transactionId), expected)
            XCTAssertEqual(page.context?["endCursor"], "e")
            XCTAssertEqual(page.context?["startCursor"], "s")
        }
    }

    func testRuntimeDependentFactoriesHandleEmptyPagesAndUnavailableRuntime() throws {
        let repository = AnyDataProviderRepository(InMemoryDataProviderRepository<TransactionHistoryItem>())
        let registry = CovGHistoryRegistry()
        let factories: [HistoryOperationFactoryProtocol] = [
            SubqueryHistoryOperationFactory(txStorage: repository, chainRegistry: registry),
            SoraSubsquidHistoryOperationFactory(txStorage: repository, chainRegistry: registry)
        ]
        for factory in factories {
            let empty = try history(factory, chain: CovGOperationFixtures.chain(history: nil))
            XCTAssertTrue(try XCTUnwrap(CovGOperationFixtures.run(empty)).transactions.isEmpty)
            let complete = try history(factory, filters: [])
            XCTAssertNil(try XCTUnwrap(CovGOperationFixtures.run(complete)).context)
        }
        registry.provider = nil
        for factory in factories {
            XCTAssertThrowsError(try CovGOperationFixtures.run(history(factory))) {
                XCTAssertTrue($0 is fearless.RuntimeProviderError)
            }
        }
    }

    private func factories(
        repository: InMemoryDataProviderRepository<TransactionHistoryItem> = InMemoryDataProviderRepository()
    ) -> [HistoryOperationFactoryProtocol] {
        let storage = AnyDataProviderRepository(repository)
        return [SubsquidHistoryOperationFactory(txStorage: storage), ArrowsquidHistoryOperationFactory(txStorage: storage),
                GiantsquidHistoryOperationFactory(txStorage: storage)]
    }

    private func history(
        _ factory: HistoryOperationFactoryProtocol, context: PaginationContext? = nil,
        chain: ChainModel? = nil, filters: [WalletTransactionHistoryFilter]? = nil
    ) throws -> CompoundOperationWrapper<AssetTransactionPageData?> {
        try factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: chain ?? CovGOperationFixtures.chain(), address: owner,
            filters: filters ?? self.filters, pagination: Pagination(count: 2, context: context)
        )
    }

    private func element(_ id: String, time: String, assetId: String? = nil) -> String {
        """
        {"id":"\(id)","timestamp":"\(time)","address":"owner",
        "transfer":{"amount":"1000000000000","from":"owner","to":"peer","success":true
        \(assetId.map { ",\"assetId\":\"\($0)\"" } ?? "")}}
        """
    }

    private func checkGraphQLErrors<T>(_ network: NetworkOperation<T>) {
        CovGOperationFixtures.checkNetworkFailures(network)
        let errorData = Data(#"{"errors":[{"message":"query rejected"}]}"#.utf8)
        XCTAssertThrowsError(try network.resultFactory.createResult(data: errorData, response: CovGOperationFixtures.response(), error: nil).get()) {
            XCTAssertEqual(($0 as? GraphQLError)?.message, "query rejected")
        }
    }
}

final class CovGHistoryRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
    var provider: RuntimeProviderProtocol?

    override init() {
        provider = CovGHistoryRuntime()
        super.init()
    }

    override func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
        provider
    }
}

final class CovGHistoryRuntime: RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    var snapshot: RuntimeSnapshot?
    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot {
        throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        try RuntimeCodingServiceStub.createWestendCodingFactory()
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { try RuntimeCodingServiceStub.createWestendCodingFactory() }
    }
}
