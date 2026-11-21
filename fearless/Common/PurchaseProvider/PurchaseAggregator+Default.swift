import Foundation

extension PurchaseAggregator {
    static func defaultAggregator(with purchaseProviders: [PurchaseProviderProtocol]?) -> PurchaseAggregator {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let defaultProviders: [PurchaseProviderProtocol] = [
            RampProvider(),
            MoonpayProviderFactory().createProvider(apiKey: config.moonPayApiKey)
        ]
        return PurchaseAggregator(providers: purchaseProviders ?? defaultProviders)
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(colorCode: R.color.colorPink()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)
    }
}
