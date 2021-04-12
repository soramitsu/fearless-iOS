import Foundation

protocol MoonpayProviderFactoryProtocol {
    func createProvider() -> PurchaseProviderProtocol
}

final class MoonpayProviderFactory: MoonpayProviderFactoryProtocol {
    func createProvider() -> PurchaseProviderProtocol {
        let provider = MoonpayProvider()

        // TODO: FLW-644 Replace with production value
        let secretKeyData = Data("sk_test_gv8uZyjSE2ifxhJyEFCGYwNaMntfsdKY".utf8)
        let signer = HmacSigner(hashFunction: .SHA256, secretKeyData: secretKeyData)
        provider.hmacSigner = signer

        return provider
    }
}
