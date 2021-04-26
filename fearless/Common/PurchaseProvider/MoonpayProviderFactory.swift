import Foundation

protocol MoonpayProviderFactoryProtocol {
    func createProvider(
        with secretKeyData: Data,
        apiKey: String
    ) -> PurchaseProviderProtocol
}

final class MoonpayProviderFactory: MoonpayProviderFactoryProtocol {
    func createProvider(
        with secretKeyData: Data,
        apiKey: String
    ) -> PurchaseProviderProtocol {
        let provider = MoonpayProvider(apiKey: apiKey)

        let signer = HmacSigner(hashFunction: .SHA256, secretKeyData: secretKeyData)
        provider.hmacSigner = signer

        return provider
    }
}
