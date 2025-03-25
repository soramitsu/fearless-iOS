import Foundation
import SSFModels

extension PurchaseAggregator {
    static func defaultAggregator(with purchaseProviders: [PurchaseProviderProtocol]?, chain: ChainModel) -> PurchaseAggregator {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let moonpaySecretKeyData = Data(MoonPayKeys.secretKey.utf8)

        let defaultProviders: [PurchaseProviderProtocol] = [
            RampProvider(),
            MoonpayProviderFactory().createProvider(
                with: moonpaySecretKeyData,
                apiKey: config.moonPayApiKey
            ),
            CoinbasePurchaseProvivder()
        ]
        return PurchaseAggregator(providers: purchaseProviders ?? defaultProviders)
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(colorCode: R.color.colorPink()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)
            .with(chainName: chain.name)
    }
}
