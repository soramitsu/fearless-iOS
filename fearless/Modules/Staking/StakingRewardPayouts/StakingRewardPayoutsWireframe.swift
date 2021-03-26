import Foundation

final class StakingRewardPayoutsWireframe: StakingRewardPayoutsWireframeProtocol {

    func showRewardDetails(from view: ControllerBackedProtocol?) {
        guard let rewardDetails = StakingRewardDetailsViewFactory.createView() else { return }
        view?.controller
            .navigationController?
            .pushViewController(rewardDetails.controller, animated: true)
    }
}
