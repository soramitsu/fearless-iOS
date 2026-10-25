import SSFModels
import XCTest
@testable import fearless

final class OklinkRequestRegressionTests: XCTestCase {
    func testQuerylessEndpointReceivesAddressSymbolAndTokenProtocol() throws {
        let asset = AssetModel(
            id: "0x11",
            name: "Token",
            symbol: "TOK",
            precision: 6,
            isUtility: false,
            isNative: false,
            ethereumType: .erc20
        )
        let url = try XCTUnwrap(OklinkHistoryOperationFactory.historyURL(
            address: "0x1234", url: XCTUnwrap(URL(string: "https://example.invalid/history")), asset: asset
        ))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertTrue(items.contains(URLQueryItem(name: "address", value: "0x1234")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "symbol", value: "TOK")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "protocolType", value: "token_20")))
    }

    func testExistingProviderParametersSurvive() throws {
        let asset = AssetModel(
            id: "0",
            name: "Native",
            symbol: "ETH",
            precision: 18,
            isUtility: true,
            isNative: true,
            ethereumType: .normal
        )
        let url = try XCTUnwrap(OklinkHistoryOperationFactory.historyURL(
            address: "0x1234", url: XCTUnwrap(URL(string: "https://example.invalid/history?chainShortName=ETH")),
            asset: asset
        ))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertTrue(items.contains(URLQueryItem(name: "chainShortName", value: "ETH")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "address", value: "0x1234")))
        XCTAssertFalse(items.contains { $0.name == "protocolType" })
    }

    func testCursorRoundTripRequestsTheNextPageAndReplacesConfiguredPage() throws {
        let asset = testAsset
        let first = try OklinkHistoryOperationFactory.mapResponse(
            response(page: "1", total: "3"), address: "0xowner", asset: asset, chain: testChain
        )
        XCTAssertEqual(first.context, ["page": "2"])
        let url = try XCTUnwrap(OklinkHistoryOperationFactory.historyURL(
            address: "0xowner",
            url: XCTUnwrap(URL(string: "https://example.invalid/history?chainShortName=ETH&page=1")),
            asset: asset, page: first.context?["page"]
        ))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.filter { $0.name == "page" }, [URLQueryItem(name: "page", value: "2")])
        XCTAssertTrue(items.contains(URLQueryItem(name: "chainShortName", value: "ETH")))
        let last = try OklinkHistoryOperationFactory.mapResponse(
            response(page: "3", total: "3"), address: "0xowner", asset: asset, chain: testChain, requestedPage: "3"
        )
        XCTAssertNil(last.context)
    }

    func testEmptyAndFilteredPagesUseProviderPaginationWithoutInventingTransactions() throws {
        let filtered = try OklinkHistoryOperationFactory.mapResponse(
            response(page: "2", total: "4", includeOtherAsset: true),
            address: "0xowner", asset: testAsset, chain: testChain, requestedPage: "2"
        )
        XCTAssertTrue(filtered.transactions.isEmpty)
        XCTAssertEqual(filtered.context, ["page": "3"])
        let empty = try OklinkHistoryOperationFactory.mapResponse(
            response(page: "1", total: "0"), address: "0xowner", asset: testAsset, chain: testChain
        )
        XCTAssertTrue(empty.transactions.isEmpty)
        XCTAssertNil(empty.context)
    }

    func testMalformedPageMetadataAndProviderFailurePropagate() throws {
        for (page, total) in [("0", "3"), ("bad", "3"), ("2", "1"), ("1", "-1"), ("1", "bad")] {
            XCTAssertThrowsError(try OklinkHistoryOperationFactory.mapResponse(
                response(page: page, total: total), address: "0xowner", asset: testAsset, chain: testChain
            )) { XCTAssertEqual($0 as? OklinkHistoryError, .invalidPagination) }
        }
        XCTAssertThrowsError(try OklinkHistoryOperationFactory.mapResponse(
            OklinkHistoryResponse(code: "500", msg: "unavailable", data: []),
            address: "0xowner", asset: testAsset, chain: testChain
        )) { XCTAssertEqual($0 as? OklinkHistoryError, .providerRejected) }
    }

    func testPageBoundaryCannotOverflowAndMalformedCursorCannotRestartHistory() throws {
        let last = try OklinkHistoryOperationFactory.mapResponse(
            response(page: String(Int.max), total: String(Int.max)),
            address: "0xowner", asset: testAsset, chain: testChain, requestedPage: String(Int.max)
        )
        XCTAssertNil(last.context)
        for cursor in ["0", "-1", "bad", "01", "+2", " 2", String(Int.max) + "0"] {
            XCTAssertNil(OklinkHistoryOperationFactory.historyURL(
                address: "0xowner", url: try XCTUnwrap(URL(string: "https://example.invalid/history")),
                asset: testAsset, page: cursor
            ))
        }
    }

    func testStaleOrAheadResponseCannotRepeatOrSkipTheRequestedPage() throws {
        for returnedPage in ["1", "3"] {
            XCTAssertThrowsError(try OklinkHistoryOperationFactory.mapResponse(
                response(page: returnedPage, total: "4"), address: "0xowner", asset: testAsset,
                chain: testChain, requestedPage: "2"
            )) { XCTAssertEqual($0 as? OklinkHistoryError, .invalidPagination) }
        }
    }

    private var testAsset: AssetModel {
        AssetModel(
            id: "0x11",
            name: "Token",
            symbol: "TOK",
            precision: 6,
            isUtility: false,
            isNative: false,
            ethereumType: .erc20
        )
    }

    private var testChain: ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: "97",
            paraId: nil,
            name: "Fixture",
            assets: [testAsset],
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            icon: nil,
            options: [.ethereum],
            externalApi: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func response(page: String, total: String, includeOtherAsset: Bool = false) -> OklinkHistoryResponse {
        let item = OklinkTransactionItem(
            txID: "tx", methodID: "", blockHash: "", height: "1", transactionTime: "1000",
            from: "0xowner", to: "0xpeer", isFromContract: false, isToContract: false,
            amount: "1", transactionSymbol: "OTHER", txFee: "0", state: "success", tokenID: "",
            tokenContractAddress: "0xother", challengeStatus: "", l1OriginHash: ""
        )
        return OklinkHistoryResponse(code: "0", msg: "", data: [OklinkData(
            page: page, limit: "20", totalPage: total, chainFullName: "Fixture", chainShortName: "FIX",
            transactionLists: includeOtherAsset ? [item] : []
        )])
    }
}
