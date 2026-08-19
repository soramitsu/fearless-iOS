import Foundation
import SSFModels

protocol ChainAccountViewModelFactoryProtocol {
    func buildChainAccountViewModel(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        mode: ChainAccountViewMode
    ) -> ChainAccountViewModel
}

class ChainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildChainAccountViewModel(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        mode: ChainAccountViewMode
    ) -> ChainAccountViewModel {
        var address = UniversalWalletAccountAddressResolver.address(
            for: chainAsset.chain,
            wallet: wallet
        )
        if address == nil,
           !UniversalWalletChainAccountSupport.isUniversalWalletChain(
               chainAsset.chain.chainId
           ),
           let chainAccountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()),
           let address1 = try? AddressFactory.address(for: chainAccountResponse.accountId, chain: chainAsset.chain) {
            address = address1
        }
        let allAssets = Array(chainAsset.chain.assets)
        let chainAssetModel = allAssets.first(where: { $0.id == chainAsset.asset.id })
        let sendButtonVisible = !UniversalWalletChainAccountSupport.chainId(
            chainAsset.chain.chainId,
            matches: UniversalWalletRegistry.taira.chainId
        ) && !UniversalWalletChainAccountSupport.chainId(
            chainAsset.chain.chainId,
            matches: UniversalWalletRegistry.nexus.chainId
        )
        // Legacy purchaseProviders no longer available; hide Buy button by default
        let buyButtonVisible = false
        let polkaswapButtonVisible = chainAsset.chain.options?.contains(.polkaswap) == true

        let xcmButtomVisible = CuratedAssetRelationshipResolver.hasCuratedXcmDestination(
            for: chainAsset
        ) && ReviewedXcmExecutionAuthority.isAvailable

        return ChainAccountViewModel(
            walletName: wallet.name,
            selectedChainName: chainAsset.chain.name,
            selectedChainIcon: chainAsset.chain.icon.map { RemoteImageViewModel(url: $0) },
            address: address,
            assetModel: chainAssetModel,
            sendButtonVisible: sendButtonVisible,
            buyButtonVisible: buyButtonVisible,
            polkaswapButtonVisible: polkaswapButtonVisible,
            xcmButtomVisible: xcmButtomVisible,
            mode: mode
        )
    }
}

extension ChainAccountViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: AssetPriceViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
