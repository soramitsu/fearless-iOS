import UIKit

class PinSetupWireframe: PinSetupWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showMain(from view: PinSetupViewProtocol?) {
        let presentingWindow = view?.controller.view.window as? ApplicationStatusPresentable
        guard let mainViewController = MainTabBarViewFactory
            .createView(presentingWindow: presentingWindow)?
            .controller else {
            return
        }

        rootAnimator.animateTransition(to: mainViewController)
    }

    func showSignup(from _: PinSetupViewProtocol?) {
        guard let signupViewController = OnboardingMainViewFactory.createViewForOnboarding()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: signupViewController)
    }
}
