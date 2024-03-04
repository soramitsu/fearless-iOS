import UIKit

final class OnboardingRouter: OnboardingRouterInput {
    private lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    private lazy var navigationController = FearlessNavigationController()

    @MainActor func showMain() async {
        guard let mainViewController = MainTabBarViewFactory.createView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: mainViewController)
    }

    @MainActor func showLogin() async {
        let onboardingView = OnboardingMainViewFactory.createViewForOnboarding()
        guard let onboardingController = onboardingView?.controller else {
            return
        }

        animateTransition(to: onboardingController)
    }

    @MainActor func showLocalAuthentication() async {
        let pincodeView = PinViewFactory.createSecuredPinView()
        guard let pincodeController = pincodeView?.controller else {
            return
        }

        animateTransition(to: pincodeController)
    }

    @MainActor func showPincodeSetup() async {
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
