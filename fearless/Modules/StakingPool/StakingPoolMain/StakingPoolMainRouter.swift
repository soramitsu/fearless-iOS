import Foundation
import UIKit

final class StakingPoolMainRouter: StakingPoolMainRouterInput {
    func showSetupAmount(
        from view: ControllerBackedProtocol?,
        amount: Decimal?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let poolStartModule = StakingPoolStartAssembly.configureModule(
            wallet: wallet,
            chainAsset: chainAsset,
            amount: amount
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: poolStartModule.view.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

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

    func showAccountsSelection(from view: ControllerBackedProtocol?) {
        guard let accountsView = AccountManagementViewFactory.createViewForSwitch() else {
            return
        }

        accountsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            accountsView.controller,
            animated: true
        )
    }

    func showStakingManagement(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        status: NominationViewStatus?,
        from view: ControllerBackedProtocol?
    ) -> StakingPoolManagementModuleInput? {
        guard let module = StakingPoolManagementAssembly.configureModule(
            chainAsset: chainAsset,
            wallet: wallet,
            status: status
        ) else {
            return nil
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: module.view.controller)

        view?.controller.present(navigationController, animated: true)

        return module.input
    }

    func showPoolValidators(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let validatorsView = YourValidatorListViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: .pool
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: validatorsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
