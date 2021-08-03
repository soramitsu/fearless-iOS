import Foundation

extension PurchaseAggregator {
    static func defaultAggregator() -> PurchaseAggregator {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let moonpaySecretKeyData = Data(MoonPayKeys.secretKey.utf8)

        let purchaseProviders: [PurchaseProviderProtocol] = [
            RampProvider(),
            MoonpayProviderFactory().createProvider(
                with: moonpaySecretKeyData,
                apiKey: config.moonPayApiKey
            )
        ]
        return PurchaseAggregator(providers: purchaseProviders)
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(colorCode: R.color.colorAccent()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)
    }
}
