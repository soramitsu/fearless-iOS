import Foundation

protocol MoonpayProviderFactoryProtocol {
    func createProvider(apiKey: String) -> PurchaseProviderProtocol
}

final class MoonpayProviderFactory: MoonpayProviderFactoryProtocol {
    func createProvider(apiKey: String) -> PurchaseProviderProtocol {
        MoonpayProvider(apiKey: apiKey)
    }
}
