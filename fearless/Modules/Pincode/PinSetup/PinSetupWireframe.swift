import UIKit

class PinSetupWireframe: PinSetupWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showMain(from view: PinSetupViewProtocol?) {
        guard let mainViewController = MainTabBarViewFactory.createView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: mainViewController)
    }

    public func showSignup(from view: PinSetupViewProtocol?) {
        guard let signupViewController = OnboardingMainViewFactory.createView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: signupViewController)
    }
}
