import Foundation
import SSFModels

final class ChainConnectionVisibilityHelper {
    func shouldHaveConnetion(_ chain: ChainModel, wallet: MetaAccountModel?) -> Bool {
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

        let isRequired = [
            isChainlinkProvider,
            hasPoolStaking,
            hasRelaychainStaking,
            hasParachainStaking
        ]
        .compactMap { $0 }
        .contains(true)

        return isRequired
    }

    private func hasVisibleAsset(_ chain: ChainModel, wallet: MetaAccountModel?) -> Bool {
        // Presentation preferences must never disconnect a network and suppress
        // background discovery. A compatible account is sufficient.
        guard let wallet else { return true }
        return wallet.fetch(for: chain.accountRequest()) != nil
    }
}
