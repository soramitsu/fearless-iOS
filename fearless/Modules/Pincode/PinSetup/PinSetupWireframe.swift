import UIKit

class PinSetupWireframe: PinSetupWireframeProtocol {
    /// The wallet lands after an unlock: a crossfade while it settles from 1.06 to 1 (kit v3 launch, part 1).
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = FWLandingAnimationCoordinator()
    private let lockState: ApplicationLockState

    init(lockState: ApplicationLockState = .shared) {
        self.lockState = lockState
    }

    func showMain(from view: PinSetupViewProtocol?) {
        let pinWindow = view?.controller.viewIfLoaded?.window
        let presentingWindow = pinWindow as? ApplicationStatusPresentable
        guard let mainViewController = MainTabBarViewFactory
            .createView(presentingWindow: presentingWindow)?
            .controller else {
            return
        }

        // The wallet goes into the PIN's own window, and only then may a re-lock that adopted this startup PIN end:
        // its unlock lets prompt windows return and take the key window.
        if let pinWindow {
            rootAnimator.animateTransition(to: mainViewController, in: pinWindow)
        } else {
            rootAnimator.animateTransition(to: mainViewController)
        }
        if let controller = view?.controller {
            lockState.unlock(from: controller)
        }
    }

    func showSignup(from _: PinSetupViewProtocol?) {
        guard let signupViewController = OnboardingMainViewFactory.createViewForOnboarding()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: signupViewController)
    }
}
