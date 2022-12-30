import Foundation

protocol StakingPoolCreateViewModelFactoryProtocol {
    func buildViewModel(
        wallet: MetaAccountModel,
        nominatorWallet: MetaAccountModel,
        stateToggler: MetaAccountModel,
        lastPoolId: UInt32?
    ) -> StakingPoolCreateViewModel
}

final class StakingPoolCreateViewModelFactory: StakingPoolCreateViewModelFactoryProtocol {
    func buildViewModel(
        wallet: MetaAccountModel,
        nominatorWallet: MetaAccountModel,
        stateToggler: MetaAccountModel,
        lastPoolId: UInt32?
    ) -> StakingPoolCreateViewModel {
        var createPoolId: Int?
        if let lastPoolId = lastPoolId {
            createPoolId = Int(lastPoolId) + 1
        }
        return StakingPoolCreateViewModel(
            poolId: createPoolId,
            depositor: wallet.name,
            root: wallet.name,
            naminator: nominatorWallet.name,
            stateToggler: stateToggler.name
        )
    }
}
