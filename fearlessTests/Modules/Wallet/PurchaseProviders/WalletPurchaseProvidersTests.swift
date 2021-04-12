import XCTest
@testable import fearless
import UIKit.UIColor

class WalletPurchaseProvidersTests: XCTestCase {
    let address = "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu"
    let assetId: WalletAssetId = .dot
    let chain = Chain.polkadot

    func testRamp() throws {
        // given
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let apiKey = "3quzr4e6wdyccndec8jzjebzar5kxxzfy2f3us5k"
        let redirectUrl = config.purchaseRedirect
        let appName = config.purchaseAppName
        let logoUrl = config.logoURL

        // swiftlint:disable next long_string
        let expectedUrl = "https://buy.ramp.network/?swapAsset=DOT&userAddress=\(address)&hostApiKey=\(apiKey)&variant=hosted-mobile&finalUrl=\(redirectUrl)&hostAppName=\(appName)&hostLogoUrl=\(logoUrl)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        let provider = RampProvider()
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(callbackUrl: config.purchaseRedirect)

        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildPurchaseAction(for: chain,
                                               assetId: assetId,
                                               address: address)
        XCTAssertEqual(actions[0].url.absoluteString, expectedUrl)
        expectation.fulfill()

        // then
        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }

    func testMoonPay() throws {
        // given
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let apiKey = "pk_live_Boi6Rl107p7XuJWBL8GJRzGWlmUSoxbz"
        let redirectUrl = config.purchaseRedirect
        let colorCode = R.color.colorAccent()!.hexRGB

        // swiftlint:disable next long_string
        let query = "apiKey=\(apiKey)&currencyCode=DOT&walletAddress=\(address)&showWalletAddressForm=true&colorCode=\(colorCode)&redirectURL=\(redirectUrl)"
            .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""

        let expectedUrl = "https://buy.moonpay.com/?\(query)&signature=KvkXAp%2Fhy0rpb2WfQ399sM9YIOS4pDXUq2n7QjCedNs%3D"

        let provider = MoonpayProviderFactory().createProvider()
            .with(colorCode: R.color.colorAccent()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)

        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildPurchaseAction(for: chain,
                                               assetId: assetId,
                                               address: address)
        XCTAssertEqual(actions[0].url.absoluteString, expectedUrl)
        expectation.fulfill()

        // then
        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
