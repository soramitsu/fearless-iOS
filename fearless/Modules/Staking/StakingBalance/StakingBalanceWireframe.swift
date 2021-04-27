final class StakingBalanceWireframe: StakingBalanceWireframeProtocol {
    func showBondMore(from _: ControllerBackedProtocol?) {
        // TODO:
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
