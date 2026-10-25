import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class AlchemyHistoryOperationFactoryTests: XCTestCase {
    private let owner = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    private let peer = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    private let contract = "0xcccccccccccccccccccccccccccccccccccccccc"
    private var native: AssetModel {
        AssetModel(id: "ETH", name: "Ether", symbol: "ETH", precision: 18, isUtility: true, isNative: true, ethereumType: .normal)
    }

    private var token: AssetModel {
        AssetModel(id: contract, name: "Token", symbol: "TOKEN", precision: 6, isUtility: false, isNative: false, ethereumType: .erc20)
    }

    func testNetworkRoutingNeverFallsBackToEthereumForAnotherChain() throws {
        for (chain, host) in [("1", "eth-mainnet"), ("56", "bnb-mainnet"), ("137", "polygon-mainnet"), ("10", "opt-mainnet"), ("42161", "arb-mainnet")] {
            XCTAssertEqual(try AlchemyHistoryNetwork.url(chainId: chain, apiKey: "synthetic-key").host, host + ".g.alchemy.com")
        }
        for id in ["01", "0x1", "97", "11155111", "unknown"] {
            XCTAssertNil(AlchemyHistoryNetwork.identifier(chainId: id))
            XCTAssertThrowsError(try AlchemyHistoryNetwork.url(chainId: id, apiKey: "synthetic-key"))
        }
        for key in ["", "key/other", "key?other", " key ", "key\n"] {
            XCTAssertThrowsError(try AlchemyHistoryNetwork.url(chainId: "1", apiKey: key))
        }
    }

    func testAssemblyReplacesLegacyOKLinkOnlyForTheSupportedCatalogChains() throws {
        let storage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> = SubstrateDataStorageFacade.shared.createRepository()
        for id in ["1", "56", "137", "10", "42161"] {
            let factory = HistoryOperationFactoriesAssembly.createOperationFactory(chain: try chain(id), txStorage: AnyDataProviderRepository(storage))
            XCTAssertTrue(factory is AlchemyHistoryOperationFactory)
        }
        let unsupported = HistoryOperationFactoriesAssembly.createOperationFactory(chain: try chain("97"), txStorage: AnyDataProviderRepository(storage))
        XCTAssertTrue(unsupported is OklinkHistoryOperationFactory)
        let custom = HistoryOperationFactoriesAssembly.createOperationFactory(chain: try chain("1", history: "https://custom.example/oklink.com/api/history"), txStorage: AnyDataProviderRepository(storage))
        XCTAssertTrue(custom is EtherscanHistoryOperationFactory)
    }

    func testOperationWrapperReturnsMappedHistoryAndHonorsTransferFilter() throws {
        let remote = HistoryRemote()
        remote.handler = { request, _ in AlchemyHistory(transfers: request.fromAddress != nil ? [try self.item(1)] : [], pageKey: nil) }
        let factory = AlchemyHistoryOperationFactory(service: remote)
        let wrapper = factory.fetchTransactionHistoryOperation(asset: native, chain: try chain("1"), address: owner, filters: [], pagination: Pagination(count: 10))
        let done = expectation(description: "history operation")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [done], timeout: 10)
        let page = try wrapper.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertEqual(page?.transactions.first?.transactionId, "hash-1")
        let excluded = factory.fetchTransactionHistoryOperation(asset: native, chain: try chain("1"), address: owner, filters: [WalletTransactionHistoryFilter(type: .transfer, selected: false)], pagination: Pagination(count: 10))
        let excludedPage = try excluded.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertTrue(excludedPage?.transactions.isEmpty == true)
        XCTAssertEqual(remote.requests.count, 2)
    }

    func testRequestUsesContractAndProviderCursorWithoutSymbolMatching() async throws {
        let remote = HistoryRemote()
        remote.handler = { request, chain in
            XCTAssertEqual(chain, "56")
            XCTAssertEqual(request.category, [.erc20])
            XCTAssertEqual(request.contractAddresses, [self.contract])
            XCTAssertEqual(request.maxCount, "0x64")
            XCTAssertEqual(request.order, .desc)
            XCTAssertTrue(request.withMetadata == true)
            return AlchemyHistory(transfers: [], pageKey: nil)
        }
        let page = try await AlchemyHistoryOperationFactory(service: remote).fetchPage(
            asset: token, chainId: "56", address: owner, pagination: Pagination(count: 500)
        )
        XCTAssertTrue(page.transactions.isEmpty)
        XCTAssertNil(page.context)
        XCTAssertEqual(remote.requests.count, 2)
        XCTAssertEqual(remote.requests[0].fromAddress, owner)
        XCTAssertEqual(remote.requests[1].toAddress, owner)
    }

    func testNativeCategoriesMatchSupportedNetworks() async throws {
        for chain in ["1", "137", "56", "10", "42161"] {
            let remote = HistoryRemote()
            remote.handler = { request, _ in
                XCTAssertEqual(request.category, ["1", "137"].contains(chain) ? [.external, .internal] : [.external])
                XCTAssertNil(request.contractAddresses)
                return AlchemyHistory(transfers: [], pageKey: nil)
            }
            _ = try await AlchemyHistoryOperationFactory(service: remote).fetchPage(
                asset: native, chainId: chain, address: owner, pagination: Pagination(count: 10)
            )
        }
    }

    func testPaginationMergesDirectionsWithoutDroppingOrReorderingOlderTransfers() async throws {
        let remote = HistoryRemote()
        remote.handler = { request, _ in
            if request.fromAddress != nil {
                if request.pageKey == nil {
                    return AlchemyHistory(transfers: [try self.item(9), try self.item(7)], pageKey: "sent-next")
                }
                XCTAssertEqual(request.pageKey, "sent-next")
                return AlchemyHistory(transfers: [try self.item(5)], pageKey: nil)
            }
            return AlchemyHistory(transfers: [try self.item(8, outgoing: false), try self.item(6, outgoing: false)], pageKey: nil)
        }
        let factory = AlchemyHistoryOperationFactory(service: remote)
        var context: PaginationContext?
        var ids: [String] = []
        for _ in 0 ..< 5 {
            let page = try await factory.fetchPage(asset: native, chainId: "1", address: owner, pagination: Pagination(count: 2, context: context))
            ids += page.transactions.map(\.transactionId)
            context = page.context
            if context == nil { break }
        }
        XCTAssertEqual(ids, [9, 8, 7, 6, 5].map { "hash-\($0)" })
        XCTAssertNil(context)
        XCTAssertEqual(remote.requests.count, 3)
    }

    func testSelfTransferIsDeduplicatedAcrossDirections() async throws {
        let remote = HistoryRemote()
        remote.handler = { _, _ in AlchemyHistory(transfers: [try self.item(1, to: self.owner)], pageKey: nil) }
        let page = try await AlchemyHistoryOperationFactory(service: remote).fetchPage(asset: native, chainId: "1", address: owner.uppercased(), pagination: Pagination(count: 10))
        XCTAssertEqual(page.transactions.count, 1)
        XCTAssertEqual(page.transactions.first?.type, TransactionType.outgoing.rawValue)
    }

    func testCursorCannotBeReusedForAnotherAccountAssetOrNetwork() async throws {
        let remote = HistoryRemote()
        remote.handler = { _, _ in AlchemyHistory(transfers: [try self.item(2), try self.item(1)], pageKey: nil) }
        let factory = AlchemyHistoryOperationFactory(service: remote)
        let first = try await factory.fetchPage(asset: native, chainId: "1", address: owner, pagination: Pagination(count: 1))
        XCTAssertNotNil(first.context)
        for (chain, address, asset) in [("56", owner, native), ("1", peer, native), ("1", owner, token)] {
            do {
                _ = try await factory.fetchPage(asset: asset, chainId: chain, address: address, pagination: Pagination(count: 1, context: first.context))
                XCTFail("Mismatched cursor accepted")
            } catch { XCTAssertTrue(error is AlchemyHistoryError) }
        }
        do {
            _ = try await factory.fetchPage(asset: native, chainId: "1", address: owner, pagination: Pagination(count: 1, context: [AlchemyHistoryOperationFactory.cursorKey: "not-base64"]))
            XCTFail("Invalid cursor accepted")
        } catch { XCTAssertTrue(error is AlchemyHistoryError) }
    }

    func testRepeatedProviderCursorFailsInsteadOfLooping() async throws {
        let remote = HistoryRemote()
        remote.handler = { _, _ in AlchemyHistory(transfers: [], pageKey: "same") }
        let factory = AlchemyHistoryOperationFactory(service: remote)
        let first = try await factory.fetchPage(asset: native, chainId: "1", address: owner, pagination: Pagination(count: 10))
        do {
            _ = try await factory.fetchPage(asset: native, chainId: "1", address: owner, pagination: Pagination(count: 10, context: first.context))
            XCTFail("Repeated remote cursor accepted")
        } catch { XCTAssertTrue(error is AlchemyHistoryError) }
    }

    func testRawAmountAndExactContractAreUsedEvenWhenProviderSymbolIsMissing() throws {
        let factory = AlchemyHistoryOperationFactory(service: HistoryRemote())
        let transfer = try item(1, category: "erc20", contract: contract.uppercased(), raw: "0x12d687", symbol: nil)
        let transaction = try XCTUnwrap(factory.transaction(from: transfer, asset: token, address: owner.uppercased()))
        XCTAssertEqual(transaction.amount.decimalValue, Decimal(string: "1.234567"))
        XCTAssertEqual(transaction.assetId, contract)
        XCTAssertEqual(transaction.transactionId, "hash-1")
        XCTAssertEqual(transaction.peerName, peer)
        XCTAssertEqual(transaction.type, TransactionType.outgoing.rawValue)
        XCTAssertNil(factory.transaction(from: transfer, asset: native, address: owner))
        XCTAssertNil(factory.transaction(from: try item(1, category: "erc20", contract: peer), asset: token, address: owner))
        XCTAssertNil(factory.transaction(from: transfer, asset: token, address: "0xdddddddddddddddddddddddddddddddddddddddd"))
    }

    func testNullableProviderMetadataDoesNotFailDecodingOtherTransfers() throws {
        let data = Data("""
        {"transfers":[{"blockNum":"0x1","uniqueId":"id","hash":"hash","from":"from","to":null,"value":null,"asset":null,"category":"erc20","metadata":null,"rawContract":{"value":null,"address":null,"decimal":null}}],"pageKey":null}
        """.utf8)
        let response = try JSONDecoder().decode(AlchemyHistory.self, from: data)
        XCTAssertEqual(response.transfers.count, 1)
        XCTAssertNil(AlchemyHistoryOperationFactory(service: HistoryRemote()).transaction(from: response.transfers[0], asset: token, address: owner))
    }

    func testTimestampAcceptsISO8601WithOrWithoutFractionalSeconds() throws {
        let transfer = try item(1)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(transfer)) as? [String: Any])
        object["metadata"] = ["blockTimestamp": "2026-09-06T00:00:01Z"]
        let withoutFraction = try JSONDecoder().decode(AlchemyHistoryElement.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(withoutFraction.timestampInSeconds, transfer.timestampInSeconds)
        XCTAssertEqual(transfer.timestampInSeconds, 1_788_652_801)
    }

    func testServiceUsesExactNetworkAndHandlesHTTPAndJSONRPCErrors() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HistoryURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel(); HistoryURLProtocol.handler = nil }
        let service = AlchemyService(session: session, apiKey: "synthetic-key")
        let request = AlchemyHistoryRequest(fromAddress: owner, category: [.external])
        HistoryURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "bnb-mainnet.g.alchemy.com")
            XCTAssertEqual(request.url?.path, "/v2/synthetic-key")
            XCTAssertEqual(request.httpMethod, "POST")
            return (200, Data("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"transfers\":[]}}".utf8))
        }
        let response = try await service.fetchTransactionHistory(request: request, chainId: "56")
        XCTAssertTrue(response.transfers.isEmpty)
        for status in [200, 401, 429, 500] {
            HistoryURLProtocol.handler = { _ in (status, Data("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"message\":\"synthetic-secret\"}}".utf8)) }
            do {
                _ = try await service.fetchTransactionHistory(request: request, chainId: "56")
                XCTFail("Provider failure became success")
            } catch {
                XCTAssertTrue(error is AlchemyHistoryError)
                XCTAssertFalse(error.localizedDescription.contains("synthetic-secret"))
            }
        }
    }

    func testRemoteFailurePropagatesInsteadOfClaimingEmptyHistory() async {
        let remote = HistoryRemote()
        remote.handler = { _, _ in throw AlchemyHistoryError.invalidResponse }
        do {
            _ = try await AlchemyHistoryOperationFactory(service: remote).fetchPage(asset: native, chainId: "1", address: owner, pagination: Pagination(count: 10))
            XCTFail("Remote failure became empty history")
        } catch { XCTAssertTrue(error is AlchemyHistoryError) }
    }

    private func item(_ order: Int, outgoing: Bool = true, category: String = "external", contract: String? = nil, raw: String = "0xde0b6b3a7640000", symbol: String? = "ETH", to: String? = nil) throws -> AlchemyHistoryElement {
        let object: [String: Any] = [
            "blockNum": "0x1", "uniqueId": "unique-\(order)", "hash": "hash-\(order)",
            "from": outgoing ? owner : peer, "to": to ?? (outgoing ? peer : owner),
            "value": 1, "asset": symbol as Any? ?? NSNull(), "category": category,
            "metadata": ["blockTimestamp": String(format: "2026-09-06T00:00:%02d.000Z", order)],
            "rawContract": ["value": raw, "address": contract as Any? ?? NSNull(), "decimal": "0x12"]
        ]
        return try JSONDecoder().decode(AlchemyHistoryElement.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func chain(_ id: String, history: String = "https://www.oklink.com/api/v5/explorer/address/transaction-list?chainShortName=ETH") throws -> ChainModel {
        let explorer = try XCTUnwrap(ChainModel.BlockExplorer(type: "etherscan", url: XCTUnwrap(URL(string: history))))
        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: id,
            paraId: nil,
            name: "EVM",
            assets: [native],
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            icon: nil,
            options: [.ethereum],
            externalApi: .init(history: explorer),
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private final class HistoryRemote: AlchemyHistoryFetching {
    var requests: [AlchemyHistoryRequest] = []
    var handler: ((AlchemyHistoryRequest, String) throws -> AlchemyHistory)?
    func fetchTransactionHistory(request: AlchemyHistoryRequest, chainId: String) async throws -> AlchemyHistory {
        requests.append(request)
        guard let handler else { throw AlchemyHistoryError.invalidResponse }
        return try handler(request, chainId)
    }
}

private final class HistoryURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: AlchemyHistoryError.invalidResponse)
            return
        }
        let (status, data) = handler(request)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
