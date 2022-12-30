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
        return ChainAccountViewModel(
            walletName: wallet.name,
            selectedChainName: chainAsset.chain.name,
            address: address,
            chainAssetModel: chainAssetModel
        )
    }
}

extension ChainAccountViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: AssetPriceViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
