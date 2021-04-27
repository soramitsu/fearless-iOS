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

    func cancel(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
