import Foundation
import SoraKeystore
import SSFModels

protocol StakingViewModelFacadeProtocol {
    func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol
    func createRewardViewModelFactory(for chainAsset: ChainAsset) -> RewardViewModelFactoryProtocol
}

final class StakingViewModelFacade: StakingViewModelFacadeProtocol {
    private let selectedMetaAccount: MetaAccountModel

    init(selectedMetaAccount: MetaAccountModel) {
        self.selectedMetaAccount = selectedMetaAccount
    }

    func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: selectedMetaAccount
        )
    }

    func createRewardViewModelFactory(for chainAsset: ChainAsset) -> RewardViewModelFactoryProtocol {
        RewardViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: selectedMetaAccount
        )
    }
}
