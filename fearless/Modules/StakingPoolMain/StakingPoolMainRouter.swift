import Foundation

final class StakingPoolMainRouter: StakingPoolMainRouterInput {
    func showChainAssetSelection(
        from view: StakingPoolMainViewInput?,
        type: AssetSelectionStakingType,
        delegate: AssetSelectionDelegate
    ) {
        let stakingFilter: AssetSelectionFilter = { chainAsset in chainAsset.staking != nil }

        guard let selectedMetaAccount = SelectedWalletSettings.shared.value,
              let selectionView = AssetSelectionViewFactory.createView(
                  delegate: delegate,
                  type: type,
                  selectedMetaAccount: selectedMetaAccount,
                  assetFilter: stakingFilter,
                  assetSelectionType: .staking
              ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        maxReward: (title: String, amount: Decimal),
        avgReward: (title: String, amount: Decimal)
    ) {
        let infoVew = ModalInfoFactory.createRewardDetails(for: maxReward, avgReward: avgReward)

        view?.controller.present(infoVew, animated: true, completion: nil)
    }
}
