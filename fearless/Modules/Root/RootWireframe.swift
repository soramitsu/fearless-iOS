import UIKit

final class RootWireframe: RootWireframeProtocol {
    func showOnboarding(on view: UIWindow) {
        let onboardingView = OnboardingMainViewFactory.createView()
        let onboardingController = onboardingView?.controller ?? UIViewController()

        let navigationController = FearlessNavigationController()
        navigationController.viewControllers = [onboardingController]

        view.rootViewController = navigationController
    }

    func showLocalAuthentication(on view: UIWindow) {}

    func showAuthVerification(on view: UIWindow) {}

    func showBroken(on view: UIWindow) {
        // normally user must not see this but on malicious devices it is possible
        view.backgroundColor = .red
    }
}
