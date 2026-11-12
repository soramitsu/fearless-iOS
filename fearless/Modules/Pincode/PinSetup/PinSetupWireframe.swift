import UIKit

class PinSetupWireframe: PinSetupWireframeProtocol {
    /// The wallet lands after an unlock: a crossfade while it settles from 1.06 to 1 (kit v3 launch, part 1).
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = FWLandingAnimationCoordinator()

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
