import Foundation
import SoraKeystore

protocol StakingViewModelFacadeProtocol {
    func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol
    func createRewardViewModelFactory(for chainAsset: ChainAsset) -> RewardViewModelFactoryProtocol
}

final class StakingViewModelFacade: StakingViewModelFacadeProtocol {
    func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)
    }

    func createRewardViewModelFactory(for chainAsset: ChainAsset) -> RewardViewModelFactoryProtocol {
        RewardViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)
    }
}
