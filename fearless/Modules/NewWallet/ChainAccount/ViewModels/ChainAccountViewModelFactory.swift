import Foundation

protocol ChainAccountViewModelFactoryProtocol {
    func buildChainAccountViewModel(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> ChainAccountViewModel
}

class ChainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildChainAccountViewModel(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> ChainAccountViewModel {
        var address: String?
        if
            let chainAccountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let address1 = try? AddressFactory.address(for: chainAccountResponse.accountId, chain: chainAsset.chain) {
            address = address1
        }
        let allAssets = Array(chainAsset.chain.assets)
        let chainAssetModel = allAssets.first(where: { $0.assetId == chainAsset.asset.id })
        let buyButtonVisible = !(chainAssetModel?.purchaseProviders?.first == nil)
        let polkaswapButtonVisible = chainAssetModel?.chain?.options?.contains(.polkaswap) == true

        var xcmButtomVisible: Bool = false
        if let availableAssets = chainAsset.chain.xcm?.availableAssets.map({ $0.lowercased() }) {
            if let displayName = chainAsset.asset.displayName?.lowercased() {
                xcmButtomVisible = availableAssets.contains(displayName)
            } else {
                let symbol = chainAsset.asset.symbol.lowercased()
                xcmButtomVisible = availableAssets.contains(symbol)
            }
        }

        return ChainAccountViewModel(
            walletName: wallet.name,
            selectedChainName: chainAsset.chain.name,
            address: address,
            chainAssetModel: chainAssetModel,
            buyButtonVisible: buyButtonVisible,
            polkaswapButtonVisible: polkaswapButtonVisible,
            xcmButtomVisible: xcmButtomVisible
        )
    }
}

extension ChainAccountViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: AssetPriceViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
