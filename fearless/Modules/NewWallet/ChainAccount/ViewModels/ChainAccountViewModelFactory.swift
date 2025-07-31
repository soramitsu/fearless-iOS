import Foundation
import SCard
import SSFModels
import SSFCrypto

protocol ChainAccountViewModelFactoryProtocol {
    func buildChainAccountViewModel(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        mode: ChainAccountViewMode,
        soraCardStatus: KYCUserStatus?
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
        mode: ChainAccountViewMode,
        soraCardStatus: KYCUserStatus?
    ) -> ChainAccountViewModel {
        var address: String?
        if
            let chainAccountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let address1 = try? AddressFactory.address(for: chainAccountResponse.accountId, chainFormat: chainAsset.chain.chainFormat(bounceable: false)) {
            address = address1
        }
        let allAssets = Array(chainAsset.chain.assets)
        let chainAssetModel = allAssets.first(where: { $0.id == chainAsset.asset.id })
        
        var availableProviders = chainAssetModel?.purchaseProviders ?? []
        if soraCardStatus != .successful {
            availableProviders = availableProviders.filter { provider in
                provider != .soracard
            }
        }
        let buyButtonVisible = !availableProviders.isEmpty
        
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
            xcmButtomVisible: xcmButtomVisible,
            mode: mode
        )
    }
}

extension ChainAccountViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: AssetPriceViewModelFactoryProtocol {}
extension ChainAccountViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
