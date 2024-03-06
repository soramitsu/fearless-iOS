import Foundation

final class OnboardingStartRouter: OnboardingStartRouterInput {
    private lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    private lazy var navigationController = FearlessNavigationController()

    func startOnboarding() {
        let onboardingModule = OnboardingAssembly.configureModule()
        guard let controller = onboardingModule?.view.controller else {
            return
        }

        navigationController.viewControllers = [controller]
        rootAnimator.animateTransition(to: navigationController)
    }
}
