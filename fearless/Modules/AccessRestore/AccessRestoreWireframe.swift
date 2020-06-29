import Foundation

final class AccessRestoreWireframe: AccessRestoreWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showNext(from view: AccessRestoreViewProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }
}
