import Foundation
import SoraFoundation

final class StakingRewardDestSetupWireframe: StakingRewardDestSetupWireframeProtocol {
    func proceed(view _: StakingRewardDestSetupViewProtocol?, rewardDestination _: RewardDestination<AccountItem>) {
        // TODO: FLW-769 https://soramitsu.atlassian.net/browse/FLW-769
        //        guard let confirmationView = StakingRewardDestConfirmViewFactory.createView(from: amount) else {
        //            return
        //        }
        //
        //        view?.controller.navigationController?.pushViewController(
        //            confirmationView.controller,
        //            animated: true
        //        )
        //    }
    }
}
