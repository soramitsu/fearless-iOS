import Foundation
import SoraFoundation
import SSFModels

final class StakingRewardDestSetupWireframe: StakingRewardDestSetupWireframeProtocol {
    func proceed(
        view: StakingRewardDestSetupViewProtocol?,
        rewardDestination: RewardDestination<ChainAccountResponse>,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let confirmationView = StakingRewardDestConfirmViewFactory.createView(
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount,
            for: rewardDestination
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }
}
