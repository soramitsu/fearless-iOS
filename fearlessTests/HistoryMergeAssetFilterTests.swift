import RobinHood
import SSFModels
import XCTest
@testable import fearless

/// The Subquery and SORA history factories keep only the opened asset's remote records, but when pending local
/// transactions existed they merged the unfiltered records, so other assets' history appeared on the first page.
final class HistoryMergeAssetFilterTests: XCTestCase {
    private let owner = "owner"

    func testSubqueryFirstPageWithPendingTransactionsKeepsOnlyTheAssetsRecords() throws {
        let registry = SoraRewardServiceRegistry()
        registry.runtime = try SoraRewardServiceRegistry.sharedRuntime()
        let factory = SubqueryHistoryOperationFactory(
            txStorage: AnyDataProviderRepository(PendingHistoryRepository(items: [Self.pending()])),
            chainRegistry: registry
        )
        let wrapper = factory.fetchTransactionHistoryOperation(
            asset: AssetModel(
                id: "dot", name: "DOT", symbol: "DOT", precision: 10, isUtility: true, isNative: true, type: .normal
            ),
            chain: Self.chain(history: .subquery),
            address: owner,
            filters: Self.filters,
            pagination: Pagination(count: 10)
        )
        let nodes = [
            Self.subqueryElement("native", assetId: nil),
            Self.subqueryElement("token", assetId: "0x0001")
        ].joined(separator: ",")
        try respond(
            wrapper,
            with: #"{"historyElements":{"nodes":[\#(nodes)],"pageInfo":{"startCursor":"s","endCursor":"e"}}}"#,
            as: SubqueryHistoryData.self
        )

        let page = try XCTUnwrap(Self.run(wrapper))

        XCTAssertEqual(Set(page.transactions.map(\.transactionId)), ["pending-hash", "native"])
    }

    func testSoraFirstPageWithPendingTransactionsKeepsOnlyTheAssetsRecords() throws {
        let registry = SoraRewardServiceRegistry()
        registry.runtime = try SoraRewardServiceRegistry.sharedRuntime()
        let factory = SoraSubsquidHistoryOperationFactory(
            txStorage: AnyDataProviderRepository(PendingHistoryRepository(items: [Self.pending()])),
            chainRegistry: registry
        )
        let asset = AssetModel(
            id: "xor", name: "XOR", symbol: "XOR", precision: 18, currencyId: "0x0200", isUtility: false, isNative: true
        )
        let wrapper = factory.fetchTransactionHistoryOperation(
            asset: asset,
            chain: Self.chain(history: .sora),
            address: owner,
            filters: Self.filters,
            pagination: Pagination(count: 10)
        )
        let edges = [
            #"{"node":{"id":"xor-transfer","timestamp":1700000000,"module":"assets","method":"transfer","data":{"assetId":"0x0200","amount":"1"}}}"#,
            #"{"node":{"id":"other-transfer","timestamp":1700000000,"module":"assets","method":"transfer","data":{"assetId":"0x0999","amount":"1"}}}"#
        ].joined(separator: ",")
        try respond(
            wrapper,
            with: #"{"historyElementsConnection":{"edges":[\#(edges)],"totalCount":2,"pageInfo":{"startCursor":"s","endCursor":"e"}}}"#,
            as: SoraSubsquidHistoryConnectionResponse.self
        )

        let page = try XCTUnwrap(Self.run(wrapper))

        XCTAssertEqual(Set(page.transactions.map(\.transactionId)), ["pending-hash", "xor-transfer"])
    }

    // MARK: - Fixtures

    private static let filters: [WalletTransactionHistoryFilter] = [
        .init(type: .transfer, selected: true), .init(type: .reward, selected: true), .init(type: .other, selected: true)
    ]

    /// Answers the factory's network request with `json` instead of calling the indexer.
    private func respond<T>(
        _ wrapper: CompoundOperationWrapper<AssetTransactionPageData?>,
        with json: String,
        as _: T.Type
    ) throws where T: Decodable {
        let network = try XCTUnwrap(wrapper.allOperations.compactMap { $0 as? NetworkOperation<T> }.first)
        network.result = .success(try JSONDecoder().decode(T.self, from: Data(json.utf8)))
    }

    private static func run(_ wrapper: CompoundOperationWrapper<AssetTransactionPageData?>) throws -> AssetTransactionPageData? {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }

    private static func chain(history: BlockExplorerType) -> ChainModel {
        ChainModel(
            rank: nil, disabled: false, chainId: "history-merge-\(history.rawValue)", parentId: nil, paraId: nil,
            name: "History \(history.rawValue)", xcm: nil, nodes: [], addressPrefix: 0, icon: nil,
            externalApi: ChainModel.ExternalApiSet(
                history: ChainModel.BlockExplorer(type: history.rawValue, url: URL(string: "https://indexer.invalid/graphql")!)
            ),
            iosMinAppVersion: nil, identityChain: nil
        )
    }

    private static func subqueryElement(_ id: String, assetId: String?) -> String {
        let asset = assetId.map { #","assetId":"\#($0)""# } ?? ""
        return #"{"id":"\#(id)","timestamp":"1700000000","address":"owner","transfer":{"amount":"1000000000000","from":"owner","to":"peer","success":true\#(asset)}}"#
    }

    /// A transfer still waiting for its block, newer than every remote record.
    private static func pending() -> TransactionHistoryItem {
        TransactionHistoryItem(
            sender: "owner", receiver: "peer", status: .pending, txHash: "pending-hash", timestamp: 1_700_000_100,
            fee: "0", blockNumber: nil, txIndex: nil, callPath: .transfer, call: nil
        )
    }
}

private struct PendingHistoryRepository: DataProviderRepositoryProtocol {
    typealias Model = TransactionHistoryItem
    let items: [TransactionHistoryItem]

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { items }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { items.first }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { items }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { items }
    }

    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { items.count }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}
