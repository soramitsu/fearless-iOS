import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

#if DEBUG
    private typealias CovGHistoryApiKeys = BlockExplorerApiKeysDebug
#else
    private typealias CovGHistoryApiKeys = BlockExplorerApiKeys
#endif

final class CovGKaiaOklinkHistoryTests: XCTestCase {
    private let address = "0x1234567890123456789012345678901234567890"
    private let peer = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
    private var savedKaiaKey = ""
    private var savedOklinkKey = ""

    override func setUp() {
        super.setUp()
        savedKaiaKey = CovGHistoryApiKeys.kaiaScanApiKey
        savedOklinkKey = CovGHistoryApiKeys.oklinkApiKey
    }

    override func tearDown() {
        CovGHistoryApiKeys.kaiaScanApiKey = savedKaiaKey
        CovGHistoryApiKeys.oklinkApiKey = savedOklinkKey
        super.tearDown()
    }

    func testKaiaNativeHistoryRequestsBearerPageMapsSortedTransfersAndNextPage() throws {
        CovGHistoryApiKeys.kaiaScanApiKey = "cov-g-kaia"
        let chain = try CovGOperationFixtures.chain(id: "8217", history: "https://mainnet-oapi.kaiascan.io/api/v1")
        let wrapper = KaiaHistoryOperationFactory().fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: chain, address: address, filters: [],
            pagination: Pagination(count: 20, context: ["kaiaPage": "2"])
        )
        let network = try XCTUnwrap(wrapper.allOperations.compactMap { $0 as? NetworkOperation<KaiaHistoryResponse> }.first)
        let request = try network.requestFactory.createRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.host, "mainnet-oapi.kaiascan.io")
        XCTAssertEqual(request.url?.path, "/api/v1/accounts/\(address)/transactions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer cov-g-kaia")
        let json = """
        {"results":[
        \(kaiaRow(hash: "0xold", time: "2026-07-23T04:55:58.177Z", from: address, to: peer, amount: "1.5", status: "Success")),
        \(kaiaRow(hash: "0xnew", time: "2026-07-23T05:55:58Z", from: peer, to: address, amount: "2", status: "Fail")),
        \(kaiaRow(hash: "0xzero", time: "2026-07-23T06:55:58Z", from: peer, to: address, amount: "0", status: "Success"))
        ],"paging":{"total_count":3,"current_page":2,"last":false,"total_page":3}}
        """
        let result = try network.resultFactory.createResult(data: Data(json.utf8), response: CovGOperationFixtures.response(), error: nil)
        _ = try result.get()
        network.result = result
        let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(page.transactions.map(\.transactionId), ["0xnew", "0xold"])
        XCTAssertEqual(page.transactions.map(\.status), [.rejected, .commited])
        XCTAssertEqual(page.transactions.map(\.type), [TransactionType.incoming.rawValue, TransactionType.outgoing.rawValue])
        XCTAssertEqual(page.transactions.last?.amount.decimalValue, Decimal(string: "1.5"))
        XCTAssertEqual(page.transactions.last?.fees.first?.amount.decimalValue, Decimal(string: "0.001"))
        XCTAssertEqual(page.context?["kaiaPage"], "3")
    }

    func testKaiaTokenHistoryUsesContractRouteAndLastPageHasNoContext() throws {
        CovGHistoryApiKeys.kaiaScanApiKey = "cov-g-kaia"
        let chain = try CovGOperationFixtures.chain(id: "1001", history: "https://kairos-oapi.kaiascan.io/api/v1")
        let token = AssetModel(id: peer, name: "Token", symbol: "TKN", precision: 18, isUtility: false, isNative: false, ethereumType: .erc20)
        let wrapper = KaiaHistoryOperationFactory().fetchTransactionHistoryOperation(
            asset: token, chain: chain, address: address, filters: [], pagination: Pagination(count: 5)
        )
        let network = try XCTUnwrap(wrapper.allOperations.compactMap { $0 as? NetworkOperation<KaiaHistoryResponse> }.first)
        let request = try network.requestFactory.createRequest()
        XCTAssertEqual(request.url?.host, "kairos-oapi.kaiascan.io")
        XCTAssertEqual(request.url?.path, "/api/v1/accounts/\(address)/token-transfers")
        XCTAssertTrue(try XCTUnwrap(request.url?.absoluteString).contains("contractAddress=\(peer)"))
        let json = """
        {"results":[{"transaction_hash":"0xtoken","datetime":"2026-07-23T04:55:58Z","from":"\(address)","to":"\(peer)",
        "amount":3,"contract":{"contract_address":"\(peer)"}}],
        "paging":{"total_count":1,"current_page":1,"last":true,"total_page":1}}
        """
        network.result = try network.resultFactory.createResult(data: Data(json.utf8), response: CovGOperationFixtures.response(), error: nil)
        let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(page.transactions.map(\.transactionId), ["0xtoken"])
        XCTAssertEqual(page.transactions.first?.assetId, peer)
        XCTAssertTrue(try XCTUnwrap(page.transactions.first).fees.isEmpty)
        XCTAssertNil(page.context)
    }

    func testKaiaResultFactoryRejectsTransportStatusAndMissingBody() throws {
        CovGHistoryApiKeys.kaiaScanApiKey = "cov-g-kaia"
        let chain = try CovGOperationFixtures.chain(id: "8217", history: "https://mainnet-oapi.kaiascan.io")
        let wrapper = KaiaHistoryOperationFactory().fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: chain, address: address, filters: [], pagination: Pagination(count: 5)
        )
        let network = try XCTUnwrap(wrapper.allOperations.compactMap { $0 as? NetworkOperation<KaiaHistoryResponse> }.first)
        let factory = network.resultFactory
        XCTAssertThrowsError(try factory.createResult(data: nil, response: nil, error: NSError(domain: "CovG.kaia", code: 41)).get()) {
            XCTAssertEqual(($0 as NSError).code, 41)
        }
        let failure = try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(URL(string: "https://fixture.invalid")), statusCode: 503, httpVersion: nil, headerFields: nil))
        XCTAssertThrowsError(try factory.createResult(data: Data("{}".utf8), response: failure, error: nil).get()) {
            XCTAssertEqual($0 as? KaiaHistoryError, .invalidHTTPResponse)
        }
        XCTAssertThrowsError(try factory.createResult(data: Data("{}".utf8), response: nil, error: nil).get()) {
            XCTAssertEqual($0 as? KaiaHistoryError, .invalidHTTPResponse)
        }
        XCTAssertThrowsError(try factory.createResult(data: nil, response: CovGOperationFixtures.response(), error: nil).get()) {
            guard case SubqueryHistoryOperationFactoryError.incorrectInputData = $0 else { return XCTFail("Wrong error \($0)") }
        }
        XCTAssertThrowsError(try factory.createResult(data: Data("invalid".utf8), response: CovGOperationFixtures.response(), error: nil).get())
        let rejected = #"{"results":[],"paging":{"total_count":0,"current_page":4,"last":true,"total_page":0}}"#
        network.result = try factory.createResult(data: Data(rejected.utf8), response: CovGOperationFixtures.response(), error: nil)
        XCTAssertThrowsError(try CovGOperationFixtures.run(wrapper)) { XCTAssertEqual($0 as? KaiaHistoryError, .providerRejected) }
    }

    func testKaiaMissingExplorerKeyAndBadAddressFailBeforeNetworking() throws {
        let factory = KaiaHistoryOperationFactory()
        let bare = try CovGOperationFixtures.chain(id: "8217", history: nil)
        let missing = factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: bare,
            address: address, filters: [], pagination: Pagination(count: 5)
        )
        XCTAssertThrowsError(try CovGOperationFixtures.run(missing)) {
            guard case SubqueryHistoryOperationFactoryError.urlMissing = $0 else { return XCTFail("Wrong error \($0)") }
        }
        let chain = try CovGOperationFixtures.chain(id: "8217", history: "https://mainnet-oapi.kaiascan.io")
        CovGHistoryApiKeys.kaiaScanApiKey = ""
        let keyless = factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: chain, address: address, filters: [], pagination: Pagination(count: 5)
        )
        XCTAssertEqual(keyless.allOperations.count, 1)
        XCTAssertThrowsError(try CovGOperationFixtures.run(keyless)) { XCTAssertEqual($0 as? KaiaHistoryError, .missingAPIKey) }
        CovGHistoryApiKeys.kaiaScanApiKey = "cov-g-kaia"
        let invalid = factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: chain, address: "owner", filters: [], pagination: Pagination(count: 5)
        )
        XCTAssertThrowsError(try CovGOperationFixtures.run(invalid)) { XCTAssertEqual($0 as? KaiaHistoryError, .invalidEndpoint) }
    }

    func testOklinkHistoryRequestsKeyedPageFiltersTokenRowsAndAdvancesPage() throws {
        CovGHistoryApiKeys.oklinkApiKey = "cov-g-oklink"
        let chain = try CovGOperationFixtures.chain(id: "195", history: "https://oklink.invalid/api/v5/explorer/address/transaction-list?chainShortName=TRON")
        let token = AssetModel(id: peer, name: "Token", symbol: "USDT", precision: 6, isUtility: false, isNative: false, ethereumType: .erc20)
        let wrapper = OklinkHistoryOperationFactory().fetchTransactionHistoryOperation(
            asset: token, chain: chain, address: address, filters: [], pagination: Pagination(count: 20, context: ["page": "2"])
        )
        let network = try XCTUnwrap(wrapper.allOperations.compactMap { $0 as? NetworkOperation<OklinkHistoryResponse> }.first)
        let request = try network.requestFactory.createRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Ok-Access-Key"), "cov-g-oklink")
        let items = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })
        XCTAssertEqual(query["page"], "2")
        XCTAssertEqual(query["address"], address)
        XCTAssertEqual(query["symbol"], "USDT")
        XCTAssertEqual(query["protocolType"], "token_20")
        XCTAssertEqual(query["chainShortName"], "TRON")
        let json = """
        {"code":"0","msg":"","data":[{"page":"2","limit":"20","totalPage":"3","chainFullName":"Tron","chainShortName":"TRON",
        "transactionLists":[\(oklinkRow(id: "old", time: "1000000", from: address, to: peer, amount: "1.5", contract: peer)),
        \(oklinkRow(id: "new", time: "2000000", from: peer, to: address, amount: "2", contract: peer.uppercased())),
        \(oklinkRow(id: "other", time: "3000000", from: peer, to: address, amount: "9", contract: "0xother"))]}]}
        """
        network.result = try network.resultFactory.createResult(data: Data(json.utf8), response: CovGOperationFixtures.response(), error: nil)
        let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(page.transactions.map(\.transactionId), ["new", "old"])
        XCTAssertEqual(page.transactions.map(\.timestamp), [2000, 1000])
        XCTAssertEqual(page.transactions.map(\.type), [TransactionType.incoming.rawValue, TransactionType.outgoing.rawValue])
        XCTAssertEqual(page.transactions.last?.fees.first?.amount.decimalValue, Decimal(string: "0.5"))
        XCTAssertEqual(page.context?["page"], "3")
    }

    func testOklinkResultFactoryAndInvalidPagesFailClosed() throws {
        let chain = try CovGOperationFixtures.chain(id: "195", history: "https://oklink.invalid/list")
        let factory = OklinkHistoryOperationFactory()
        let wrapper = factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: chain, address: address, filters: [], pagination: Pagination(count: 20)
        )
        let network = try XCTUnwrap(wrapper.allOperations.compactMap { $0 as? NetworkOperation<OklinkHistoryResponse> }.first)
        XCTAssertThrowsError(try network.resultFactory.createResult(data: nil, response: nil, error: NSError(domain: "CovG.oklink", code: 42)).get()) {
            XCTAssertEqual(($0 as NSError).code, 42)
        }
        XCTAssertThrowsError(try network.resultFactory.createResult(data: Data("{}".utf8), response: nil, error: nil).get()) {
            XCTAssertEqual($0 as? OklinkHistoryError, .invalidHTTPResponse)
        }
        let rejected = #"{"code":"50011","msg":"limit","data":[]}"#
        XCTAssertThrowsError(try network.resultFactory.createResult(data: Data(rejected.utf8), response: CovGOperationFixtures.response(), error: nil).get()) {
            XCTAssertEqual($0 as? OklinkHistoryError, .providerRejected)
        }
        let empty = #"{"code":"0","msg":"","data":[]}"#
        network.result = try network.resultFactory.createResult(data: Data(empty.utf8), response: CovGOperationFixtures.response(), error: nil)
        let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertTrue(page.transactions.isEmpty)
        XCTAssertNil(page.context)
        let invalidPage = factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: chain, address: address, filters: [],
            pagination: Pagination(count: 20, context: ["page": "02"])
        )
        XCTAssertThrowsError(try CovGOperationFixtures.run(invalidPage)) {
            guard case SubqueryHistoryOperationFactoryError.urlMissing = $0 else { return XCTFail("Wrong error \($0)") }
        }
        let bare = try CovGOperationFixtures.chain(history: nil)
        let noExplorer = factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: bare, address: address,
            filters: [], pagination: Pagination(count: 20)
        )
        XCTAssertThrowsError(try CovGOperationFixtures.run(noExplorer)) {
            guard case SubqueryHistoryOperationFactoryError.urlMissing = $0 else { return XCTFail("Wrong error \($0)") }
        }
    }

    private func kaiaRow(hash: String, time: String, from: String, to: String, amount: String, status: String) -> String {
        """
        {"transaction_hash":"\(hash)","datetime":"\(time)","from":"\(from)","to":"\(to)","amount":\(amount),
        "transaction_fee":0.001,"status":{"status":"\(status)"}}
        """
    }

    private func oklinkRow(id: String, time: String, from: String, to: String, amount: String, contract: String) -> String {
        """
        {"txId":"\(id)","methodId":"","blockHash":"0x","height":"1","transactionTime":"\(time)","from":"\(from)","to":"\(to)",
        "isFromContract":false,"isToContract":false,"amount":"\(amount)","transactionSymbol":"USDT","txFee":"0.5","state":"success",
        "tokenId":"","tokenContractAddress":"\(contract)","challengeStatus":"","l1OriginHash":""}
        """
    }
}
