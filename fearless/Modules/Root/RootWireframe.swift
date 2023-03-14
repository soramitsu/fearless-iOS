import UIKit

final class RootWireframe: RootWireframeProtocol {
    func showSplash(splashView: ControllerBackedProtocol?, on window: UIWindow) {
        window.rootViewController = splashView?.controller
    }

    func showOnboarding(on window: UIWindow) {
        let onboardingView = OnboardingMainViewFactory.createViewForOnboarding()
        let onboardingController = onboardingView?.controller ?? UIViewController()

        let navigationController = FearlessNavigationController()
        navigationController.viewControllers = [onboardingController]

        window.rootViewController = navigationController
    }

    func showLocalAuthentication(on window: UIWindow) {
        let pincodeView = PinViewFactory.createSecuredPinView()
        let pincodeController = pincodeView?.controller ?? UIViewController()

        window.rootViewController = pincodeController
    }

    func showPincodeSetup(on window: UIWindow) {
        guard let controller = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        window.rootViewController = controller
    }

    func showBroken(on window: UIWindow) {
        // normally user must not see this but on malicious devices it is possible
        window.backgroundColor = .clear
    }

    func showEducationStories(on window: UIWindow) {
        guard let viewController = EducationStoriesAssembly.configureModule()?.controller else {
            return
        }

        window.rootViewController = viewController
    }
}
