import Foundation
import SSFModels

final class ChainConnectionVisibilityHelper {
    func shouldHaveConnetion(_ chain: ChainModel, wallet: MetaAccountModel?) -> Bool {
        return true
        let hasVisibleAsset = hasVisibleAsset(chain, wallet: wallet)
        let isRequaredConnection = isChainWithRequaredConnection(chain)

        let shouldSetConnection = [
            hasVisibleAsset,
            isRequaredConnection
        ].contains(true)
        return shouldSetConnection
    }

    private func isChainWithRequaredConnection(_ chain: ChainModel) -> Bool {
        let isChainlinkProvider = chain.options?.contains(.chainlinkProvider)
        let hasPoolStaking = chain.options?.contains(.poolStaking)
        let hasRelaychainStaking = chain.assets.compactMap { $0.staking }.contains(where: { $0.isRelaychain })
        let hasParachainStaking = chain.assets.compactMap { $0.staking }.contains(where: { $0.isParachain })

        let isRequared = [
            isChainlinkProvider,
            hasPoolStaking,
            hasRelaychainStaking,
            hasParachainStaking
        ]
        .compactMap { $0 }
        .contains(true)

        return isRequared
    }

    private func hasVisibleAsset(_ chain: ChainModel, wallet: MetaAccountModel?) -> Bool {
        guard let wallet, wallet.assetsVisibility.isNotEmpty else {
            return true
        }
        let chainAssetIds = chain.chainAssets.map { $0.identifier }
        let hasVisible = wallet.assetsVisibility.contains(where: { chainAssetIds.contains($0.assetId) && !$0.hidden })
        return hasVisible
    }
}
