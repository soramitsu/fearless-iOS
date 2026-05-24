import XCTest
@testable import fearless
import SSFModels
import UIKit

final class WalletPurchaseProvidersTests: XCTestCase {
    private let address = "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu"

    func testRampProvider_whenConfigured_thenBuildsHostedMobileUrl() throws {
        let callbackUrl = URL(string: "fearless://fearless.io/redirect")!
        let logoUrl = URL(string: "https://example.com/logo.png")!
        let asset = makeAsset(symbol: "dot")

        let provider = RampProvider()
            .with(appName: "Fearless Wallet")
            .with(logoUrl: logoUrl)
            .with(callbackUrl: callbackUrl)

        let action = try XCTUnwrap(provider.buildPurchaseActions(asset: asset, address: address).first)
        let components = try XCTUnwrap(URLComponents(url: action.url, resolvingAgainstBaseURL: false))
        let query = queryItems(from: components)

        XCTAssertEqual(action.title, "Ramp")
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "app.ramp.network")
        XCTAssertEqual(query["swapAsset"], "DOT")
        XCTAssertEqual(query["userAddress"], address)
        XCTAssertEqual(query["hostApiKey"], RampProvider.pubToken)
        XCTAssertEqual(query["variant"], "hosted-mobile")
        XCTAssertEqual(query["finalUrl"], callbackUrl.absoluteString)
        XCTAssertEqual(query["hostAppName"], "Fearless Wallet")
        XCTAssertNotNil(query["hostLogoUrl"])
    }

    func testMoonpayProvider_whenConfigured_thenBuildsSignedUrl() throws {
        let callbackUrl = URL(string: "fearless://fearless.io/redirect")!
        let provider = MoonpayProviderFactory()
            .createProvider(with: Data("secret".utf8), apiKey: "test-api-key")
            .with(colorCode: "#FF3366")
            .with(callbackUrl: callbackUrl)

        let action = try XCTUnwrap(
            provider.buildPurchaseActions(asset: makeAsset(symbol: "DOT"), address: address).first
        )
        let components = try XCTUnwrap(URLComponents(url: action.url, resolvingAgainstBaseURL: false))
        let query = queryItems(from: components)

        XCTAssertEqual(action.title, "Moonpay")
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "buy.moonpay.com")
        XCTAssertEqual(query["apiKey"], "test-api-key")
        XCTAssertEqual(query["currencyCode"], "DOT")
        XCTAssertEqual(query["walletAddress"], address)
        XCTAssertEqual(query["showWalletAddressForm"], "true")
        XCTAssertEqual(query["colorCode"], "#FF3366")
        XCTAssertEqual(query["redirectURL"], callbackUrl.absoluteString)
        XCTAssertFalse(query["signature"]?.isEmpty ?? true)
    }

    func testPurchaseAggregator_whenConfigured_thenForwardsConfigurationAndAggregatesActions() throws {
        let firstProvider = MockPurchaseProvider(title: "First")
        let secondProvider = MockPurchaseProvider(title: "Second")
        let logoUrl = URL(string: "https://example.com/logo.png")!
        let callbackUrl = URL(string: "fearless://fearless.io/redirect")!
        let asset = makeAsset(symbol: "KSM")

        let actions = PurchaseAggregator(providers: [firstProvider, secondProvider])
            .with(appName: "Fearless Wallet")
            .with(logoUrl: logoUrl)
            .with(colorCode: "#FF3366")
            .with(callbackUrl: callbackUrl)
            .buildPurchaseActions(asset: asset, address: address)

        XCTAssertEqual(actions.map(\.title), ["First", "Second"])
        XCTAssertEqual(firstProvider.appName, "Fearless Wallet")
        XCTAssertEqual(secondProvider.logoUrl, logoUrl)
        XCTAssertEqual(firstProvider.colorCode, "#FF3366")
        XCTAssertEqual(secondProvider.callbackUrl, callbackUrl)
        XCTAssertEqual(firstProvider.assetSymbol, "KSM")
        XCTAssertEqual(secondProvider.address, address)
    }

    func testDefaultPurchaseAggregator_whenCustomProvidersInjected_thenUsesInjectedConfig() throws {
        let provider = MockPurchaseProvider(title: "Injected")
        let logoUrl = URL(string: "https://example.com/injected-logo.png")!
        let callbackUrl = URL(string: "fearless://injected/redirect")!
        let configSource = PurchaseAggregatorConfigSourceStub(
            moonPayApiKey: "unused-api-key",
            purchaseAppName: "Injected Wallet",
            logoURL: logoUrl,
            purchaseRedirect: callbackUrl
        )
        let moonpayProviderFactory = MoonpayProviderFactorySpy()

        let actions = PurchaseAggregator.defaultAggregator(
            with: [provider],
            configSource: configSource,
            moonpaySecretKey: "unused-secret",
            moonpayProviderFactory: moonpayProviderFactory
        ).buildPurchaseActions(asset: makeAsset(symbol: "KSM"), address: address)

        XCTAssertEqual(actions.map(\.title), ["Injected"])
        XCTAssertEqual(provider.appName, "Injected Wallet")
        XCTAssertEqual(provider.logoUrl, logoUrl)
        XCTAssertEqual(provider.colorCode, R.color.colorPink()!.hexRGB)
        XCTAssertEqual(provider.callbackUrl, callbackUrl)
        XCTAssertEqual(provider.assetSymbol, "KSM")
        XCTAssertEqual(provider.address, address)
        XCTAssertFalse(moonpayProviderFactory.didCreateProvider)
    }

    func testPurchaseAggregator_whenCoinbaseAlreadyConfigured_thenStillAggregatesCustomProviders() throws {
        let provider = MockPurchaseProvider(title: "Custom")
        let asset = makeAsset(symbol: "KSM")

        let actions = PurchaseAggregator(providers: [CoinbasePurchaseProvider(), provider])
            .buildPurchaseActions(asset: asset, address: address)

        XCTAssertEqual(actions.map(\.title), ["Custom"])
        XCTAssertEqual(provider.assetSymbol, "KSM")
        XCTAssertEqual(provider.address, address)
    }

    func testCoinbaseProvider_whenAssetSupported_thenBuildsPayUrl() throws {
        let provider = CoinbasePurchaseProvider(
            sessionTokenProvider: { "coinbase-token" },
            iconProvider: { UIImage() }
        )

        let action = try XCTUnwrap(
            provider.buildPurchaseActions(asset: makeAsset(symbol: "dot"), address: address).first
        )
        let components = try XCTUnwrap(URLComponents(url: action.url, resolvingAgainstBaseURL: false))
        let query = queryItems(from: components)

        XCTAssertEqual(action.title, "Coinbase")
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "pay.coinbase.com")
        XCTAssertEqual(components.path, "/buy/select-asset")
        XCTAssertEqual(query["sessionToken"], "coinbase-token")
        XCTAssertEqual(query["defaultNetwork"], "polkadot")
        XCTAssertEqual(query["defaultAsset"], "DOT")
        XCTAssertEqual(query["partnerUserRef"], address)
    }

    func testCoinbaseProvider_whenAssetUnsupportedOrConfigurationMissing_thenReturnsNoActions() {
        let unsupportedActions = CoinbasePurchaseProvider(
            sessionTokenProvider: { "coinbase-token" },
            iconProvider: { UIImage() }
        ).buildPurchaseActions(asset: makeAsset(symbol: "KSM"), address: address)
        let missingTokenActions = CoinbasePurchaseProvider(
            sessionTokenProvider: { nil },
            iconProvider: { UIImage() }
        ).buildPurchaseActions(asset: makeAsset(symbol: "DOT"), address: address)
        let missingIconActions = CoinbasePurchaseProvider(
            sessionTokenProvider: { "coinbase-token" },
            iconProvider: { nil }
        ).buildPurchaseActions(asset: makeAsset(symbol: "DOT"), address: address)

        XCTAssertTrue(unsupportedActions.isEmpty)
        XCTAssertTrue(missingTokenActions.isEmpty)
        XCTAssertTrue(missingIconActions.isEmpty)
    }

    func testCoinbaseKeys_whenRead_thenUseEnvironmentBackedValues() {
        let environment = ProcessInfo.processInfo.environment
        let sessionToken = environment["COINBASE_SESSION_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedSessionToken = sessionToken?.isEmpty == false ? sessionToken : nil

        XCTAssertEqual(CoinbaseKeys.sessionToken, expectedSessionToken)

        if let environmentAppId = environment["COINBASE_APP_ID"] {
            XCTAssertEqual(CoinbaseKeys.appId, environmentAppId)
        } else {
            _ = CoinbaseKeys.appId
        }
    }

    private func queryItems(from components: URLComponents) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    private func makeAsset(symbol: String) -> AssetModel {
        ChainModelGenerator.generateAssetWithId("asset-\(symbol)", symbol: symbol)
    }
}

private struct PurchaseAggregatorConfigSourceStub: PurchaseAggregatorConfigSource {
    let moonPayApiKey: String
    let purchaseAppName: String
    let logoURL: URL
    let purchaseRedirect: URL
}

private final class MoonpayProviderFactorySpy: MoonpayProviderFactoryProtocol {
    private(set) var didCreateProvider = false

    func createProvider(with secretKeyData: Data, apiKey: String) -> PurchaseProviderProtocol {
        _ = secretKeyData
        _ = apiKey
        didCreateProvider = true
        return MockPurchaseProvider(title: "Moonpay")
    }
}

private final class MockPurchaseProvider: PurchaseProviderProtocol {
    let title: String
    var appName: String?
    var logoUrl: URL?
    var colorCode: String?
    var callbackUrl: URL?
    var assetSymbol: String?
    var address: String?

    init(title: String) {
        self.title = title
    }

    func with(appName: String) -> Self {
        self.appName = appName
        return self
    }

    func with(logoUrl: URL) -> Self {
        self.logoUrl = logoUrl
        return self
    }

    func with(colorCode: String) -> Self {
        self.colorCode = colorCode
        return self
    }

    func with(callbackUrl: URL) -> Self {
        self.callbackUrl = callbackUrl
        return self
    }

    func buildPurchaseActions(asset: AssetModel, address: String) -> [PurchaseAction] {
        assetSymbol = asset.symbol
        self.address = address

        return [
            PurchaseAction(
                title: title,
                url: URL(string: "https://example.com/\(title.lowercased())")!,
                icon: UIImage()
            )
        ]
    }
}
