import Foundation
import UIKit

final class EducationStoriesRouter: EducationStoriesRouterProtocol {
    private lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    private lazy var navigationController = FearlessNavigationController()

    func showMain() {
        guard let mainViewController = MainTabBarViewFactory.createView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: mainViewController)
    }

    func showOnboarding() {
        let onboardingView = OnboardingMainViewFactory.createViewForOnboarding()
        let onboardingController = onboardingView?.controller ?? UIViewController()

        animateTransition(to: onboardingController)
    }

    func showLocalAuthentication() {
        let pincodeView = PinViewFactory.createSecuredPinView()
        let pincodeController = pincodeView?.controller ?? UIViewController()

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
