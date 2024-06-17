import UIKit

final class OnboardingRouter: OnboardingRouterInput {
    private lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    private lazy var navigationController = FearlessNavigationController()

    func showMain() {
        guard let mainViewController = MainTabBarViewFactory.createView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: mainViewController)
    }

    func showLogin() {
        let onboardingView = OnboardingMainViewFactory.createViewForOnboarding()
        guard let onboardingController = onboardingView?.controller else {
            return
        }

        animateTransition(to: onboardingController)
    }

    func showLocalAuthentication() {
        let pincodeView = PinViewFactory.createSecuredPinView()
        guard let pincodeController = pincodeView?.controller else {
            return
        }

        animateTransition(to: pincodeController)
    }

    func showPincodeSetup() {
        guard let controller = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        animateTransition(to: controller)
    }

    private func animateTransition(to viewConstoller: UIViewController) {
        navigationController.viewControllers = [viewConstoller]
        rootAnimator.animateTransition(to: navigationController)
    }
}
