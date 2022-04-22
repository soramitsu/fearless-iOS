import Foundation
import SoraKeystore

protocol StakingViewModelFacadeProtocol {
    func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol
    func createRewardViewModelFactory(for chainAsset: ChainAsset) -> RewardViewModelFactoryProtocol
}

final class StakingViewModelFacade: StakingViewModelFacadeProtocol {
    private let settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }

    func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            settings: settings
        )
    }

    func createRewardViewModelFactory(for chainAsset: ChainAsset) -> RewardViewModelFactoryProtocol {
        RewardViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            settings: settings
        )
    }
}
