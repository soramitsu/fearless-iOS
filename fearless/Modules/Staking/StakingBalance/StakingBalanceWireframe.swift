final class StakingBalanceWireframe: StakingBalanceWireframeProtocol {
    func showBondMore(from view: ControllerBackedProtocol?) {
        guard let bondMoreView = StakingBondMoreViewFactory.createView() else { return }
        let navigationController = FearlessNavigationController(rootViewController: bondMoreView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showUnbond(from _: ControllerBackedProtocol?) {
        // TODO:
    }

    func showRedeem(from _: ControllerBackedProtocol?) {
        // TODO:
    }

    func showRebond(from _: ControllerBackedProtocol?, option _: StakingRebondOption) {
        // TODO:
    }

    func cancel(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
