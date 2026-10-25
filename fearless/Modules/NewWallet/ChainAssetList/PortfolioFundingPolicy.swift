import Foundation
import SSFModels

enum PortfolioFundingAction {
    case receive
    case buy
}

/// Funding starts with an exact registry asset and an existing public account.
/// Provider metadata is required for Buy; a symbol is never a network selector.
enum PortfolioFundingPolicy {
    static func candidates(
        _ assets: [ChainAsset],
        wallet: MetaAccountModel,
        action: PortfolioFundingAction
    ) -> [ChainAsset] {
        var seen = Set<AssetKey>()
        return assets.filter { asset in
            let trust = AssetTrustResolver.metadataTrust(for: asset)
            guard !asset.chain.disabled, trust.trust == .verified, trust.provenance == .registry,
                  address(for: asset, wallet: wallet) != nil,
                  seen.insert(asset.assetKey).inserted else { return false }
            if action == .buy {
                return !PortfolioTestnetChainList.bundled.isTestnet(asset.chain) && supportsPurchase(asset) && asset
                    .asset.purchaseProviders?.isEmpty == false
            }
            return true
        }.sorted {
            ($0.chain.rank ?? .max, $0.asset.symbolUppercased, $0.chain.name, $0.chain.chainId, $0.asset.id) <
                ($1.chain.rank ?? .max, $1.asset.symbolUppercased, $1.chain.name, $1.chain.chainId, $1.asset.id)
        }
    }

    /// The retained purchase-provider fixture explicitly binds DOT to Polkadot.
    /// No repository evidence binds other symbol-only provider codes to a chain.
    static func supportsPurchase(_ asset: ChainAsset) -> Bool {
        asset.chain.chainId == "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3" &&
            asset.asset.id == "887a17c7-1370-4de0-97dd-5422e294fa75" &&
            asset.asset.symbolUppercased == "DOT" && asset.asset.isUtility
    }

    static func address(for asset: ChainAsset, wallet: MetaAccountModel) -> String? {
        UniversalWalletAccountAddressResolver.address(for: asset.chain, wallet: wallet)
    }

    static func purchaseActions(for asset: ChainAsset, wallet: MetaAccountModel) -> [PurchaseAction] {
        guard candidates([asset], wallet: wallet, action: .buy).count == 1,
              let address = address(for: asset, wallet: wallet) else { return [] }
        let providers: [PurchaseProviderProtocol] = (asset.asset.purchaseProviders ?? []).map { provider in
            switch provider {
            case .moonpay:
                return MoonpayProviderFactory().createProvider(
                    with: Data(MoonPayKeys.secretKey.utf8),
                    apiKey: ApplicationConfig.shared.moonPayApiKey
                )
            case .ramp:
                return RampProvider()
            }
        }
        let allowedTitles = Set((asset.asset.purchaseProviders ?? [])
            .map { $0 == .moonpay ? MoonpayProvider.Constants.title : RampProvider.Constants.title })
        // The legacy aggregator adds Coinbase generically. The funding entry only
        // exposes providers explicitly declared for this exact registry asset.
        return PurchaseAggregator.defaultAggregator(with: providers).buildPurchaseActions(
            asset: asset.asset,
            address: address
        ).filter { allowedTitles.contains($0.title) }
    }
}
