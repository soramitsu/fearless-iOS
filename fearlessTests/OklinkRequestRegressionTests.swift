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
}
