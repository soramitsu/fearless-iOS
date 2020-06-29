import Foundation

final class AccessBackupWireframe: AccessBackupWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showNext(from view: AccessBackupViewProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }
}
