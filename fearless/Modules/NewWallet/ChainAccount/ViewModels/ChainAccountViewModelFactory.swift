import Foundation
import SSFModels

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
        let chainAssetModel = allAssets.first(where: { $0.id == chainAsset.asset.id })
        let buyButtonVisible = !(chainAssetModel?.purchaseProviders?.first == nil)
        let polkaswapButtonVisible = chainAsset.chain.options?.contains(.polkaswap) == true

        var xcmButtomVisible: Bool = false
        if let availableAssets = chainAsset.chain.xcm?.availableAssets.map({ $0.symbol.lowercased() }) {
            let symbol = chainAsset.asset.symbol.lowercased()
            xcmButtomVisible = availableAssets.contains(symbol)
            if availableAssets.contains(symbol) {
                xcmButtomVisible = true
            } else if symbol.lowercased().hasPrefix("xc") {
                let modifySymbol = String(symbol.dropFirst(2)).lowercased()
                xcmButtomVisible = availableAssets.contains(modifySymbol)
            }
        }

        return ChainAccountViewModel(
            walletName: wallet.name,
            selectedChainName: chainAsset.chain.name,
            selectedChainIcon: chainAsset.chain.icon.map { RemoteImageViewModel(url: $0) },
            address: address,
            assetModel: chainAssetModel,
            buyButtonVisible: buyButtonVisible,
            polkaswapButtonVisible: polkaswapButtonVisible,
            xcmButtomVisible: xcmButtomVisible
        )
    }
}

extension ChainAccountViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: AssetPriceViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
