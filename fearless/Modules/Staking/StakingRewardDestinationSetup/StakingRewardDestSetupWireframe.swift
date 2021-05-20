import Foundation
import SoraFoundation

final class StakingRewardDestSetupWireframe: StakingRewardDestSetupWireframeProtocol {
    func proceed(view: StakingRewardDestSetupViewProtocol?, rewardDestination: RewardDestination<AccountItem>) {
        guard let confirmationView = StakingRewardDestConfirmViewFactory.createView(for: rewardDestination) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }
}
