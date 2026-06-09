import Foundation

protocol PurchaseAggregatorConfigSource {
    var moonPayApiKey: String { get }
    var purchaseAppName: String { get }
    var logoURL: URL { get }
    var purchaseRedirect: URL { get }
}

extension ApplicationConfig: PurchaseAggregatorConfigSource {}

extension PurchaseAggregator {
    static func defaultAggregator(
        with purchaseProviders: [PurchaseProviderProtocol]?,
        configSource: PurchaseAggregatorConfigSource = ApplicationConfig.shared,
        moonpaySecretKey: String = MoonPayKeys.secretKey,
        moonpayProviderFactory: MoonpayProviderFactoryProtocol = MoonpayProviderFactory()
    ) -> PurchaseAggregator {
        let providers = purchaseProviders ?? [
            RampProvider(),
            moonpayProviderFactory.createProvider(
                with: Data(moonpaySecretKey.utf8),
                apiKey: configSource.moonPayApiKey
            )
        ]

        return PurchaseAggregator(providers: providers)
            .with(appName: configSource.purchaseAppName)
            .with(logoUrl: configSource.logoURL)
            .with(colorCode: R.color.colorPink()!.hexRGB)
            .with(callbackUrl: configSource.purchaseRedirect)
    }
}
