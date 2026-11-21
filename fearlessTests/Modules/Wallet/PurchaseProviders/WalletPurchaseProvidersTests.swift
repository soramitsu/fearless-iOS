import XCTest
@testable import fearless
import SSFModels

final class WalletPurchaseProvidersTests: XCTestCase {
    func testMoonPayUrlIsUnsignedAndLeavesTheAddressToTheUser() throws {
        let provider = MoonpayProvider(apiKey: "pk_fixture")
            .with(colorCode: "#FF009A")
            .with(callbackUrl: try XCTUnwrap(URL(string: "fearless://fearless.io/redirect")))

        let url = try XCTUnwrap(provider.buildURLForToken("DOT"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let names = Set(items.map(\.name))

        XCTAssertEqual(url.host, "buy.moonpay.com")
        XCTAssertEqual(items.first { $0.name == "apiKey" }?.value, "pk_fixture")
        XCTAssertEqual(items.first { $0.name == "currencyCode" }?.value, "DOT")
        XCTAssertEqual(items.first { $0.name == "showWalletAddressForm" }?.value, "true")
        XCTAssertTrue(names.contains("redirectURL"))
        // A walletAddress needs a server-made signature; the app must send neither.
        XCTAssertFalse(names.contains("walletAddress"))
        XCTAssertFalse(names.contains("signature"))
    }

    func testMoonPayPurchaseActionIgnoresTheWalletAddress() throws {
        let provider = MoonpayProviderFactory().createProvider(apiKey: "pk_fixture")
        let asset = try JSONDecoder().decode(
            AssetModel.self,
            from: Data(#"{"id":"dot","name":"Polkadot","symbol":"DOT","precision":10}"#.utf8)
        )

        let actions = provider.buildPurchaseActions(asset: asset, address: "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu")

        XCTAssertEqual(actions.map(\.title), [MoonpayProvider.Constants.title])
        XCTAssertFalse(try XCTUnwrap(actions.first).url.absoluteString.contains("15cfSaBc"))
    }
}
