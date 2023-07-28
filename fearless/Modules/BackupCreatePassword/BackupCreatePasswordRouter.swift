import Foundation

final class BackupCreatePasswordRouter: BackupCreatePasswordRouterInput {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showPinSetup() {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }
        rootAnimator.animateTransition(to: pincodeViewController)
    }

    func dismiss(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(animated: true)
    }

    func pop(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
