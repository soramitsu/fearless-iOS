final class StakingBondMoreWireframe: StakingBondMoreWireframeProtocol {
    func showConfirmation(from _: ControllerBackedProtocol?) {
        // TODO: FLW-772
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
