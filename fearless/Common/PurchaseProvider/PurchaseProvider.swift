import Foundation

struct PurchaseAction {
    let title: String
    let url: URL
}

protocol PurchaseProviderProtocol {
    func with(appName: String) -> Self
    func with(logoUrl: URL) -> Self
    func with(callbackUrl: URL) -> Self
    func buildPurchaseAction(for chain: Chain,
                             assetId: WalletAssetId?,
                             address: String) -> [PurchaseAction]
}

final class PurchaseAggregator {
    private var providers: [PurchaseProviderProtocol]

    init(providers: [PurchaseProviderProtocol]) {
        self.providers = providers
    }
}

extension PurchaseAggregator: PurchaseProviderProtocol {
    func with(appName: String) -> Self {
        providers = providers.map { $0.with(appName: appName) }
        return self
    }

    func with(logoUrl: URL) -> Self {
        providers = providers.map { $0.with(logoUrl: logoUrl) }
        return self
    }

    func with(callbackUrl: URL) -> Self {
        providers = providers.map { $0.with(callbackUrl: callbackUrl) }
        return self
    }

    func buildPurchaseAction(for chain: Chain,
                             assetId: WalletAssetId?,
                             address: String) -> [PurchaseAction] {
        providers.flatMap { $0.buildPurchaseAction(for: chain, assetId: assetId, address: address) }
    }
}
