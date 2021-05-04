final class StakingBalanceWireframe: StakingBalanceWireframeProtocol {
    func showBondMore(from _: ControllerBackedProtocol?) {
        // TODO:
    }

    func showUnbond(from view: ControllerBackedProtocol?) {
        guard let unbondView = StakingUnbondSetupViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: unbondView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRedeem(from view: ControllerBackedProtocol?) {
        guard let redeemView = StakingRedeemViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: redeemView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRebond(from _: ControllerBackedProtocol?, option _: StakingRebondOption) {
        // TODO:
    }

    func cancel(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
