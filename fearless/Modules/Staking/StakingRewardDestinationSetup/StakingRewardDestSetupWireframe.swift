import Foundation

final class StakingRewardDestSetupWireframe: StakingRewardDestSetupWireframeProtocol {
    func close(view: StakingRewardDestSetupViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func proceed(view _: StakingRewardDestSetupViewProtocol?) {
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
