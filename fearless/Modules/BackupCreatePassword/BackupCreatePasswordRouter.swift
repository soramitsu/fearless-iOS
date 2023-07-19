import Foundation

final class BackupCreatePasswordRouter: BackupCreatePasswordRouterInput {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showPinSetup() {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }
        rootAnimator.animateTransition(to: pincodeViewController)
    }
}
