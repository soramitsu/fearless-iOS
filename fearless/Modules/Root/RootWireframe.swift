import UIKit

final class RootWireframe: RootWireframeProtocol {
    func showOnboarding(on view: UIWindow) {
        let onboardingView = OnboardingMainViewFactory.createView()
        let onboardingController = onboardingView?.controller ?? UIViewController()

        let navigationController = FearlessNavigationController()
        navigationController.viewControllers = [onboardingController]

        view.rootViewController = navigationController
    }

    func showAccountConfirmation(on view: UIWindow) {
        let confirmationView = AccountConfirmViewFactory.createView()
        let confirmationController = confirmationView?.controller ?? UIViewController()

        let navigationController = FearlessNavigationController()
        navigationController.viewControllers = [confirmationController]

        view.rootViewController = navigationController
    }

    func showLocalAuthentication(on view: UIWindow) {
        let pincodeView = PinViewFactory.createSecuredPinView()
        let pincodeController = pincodeView?.controller ?? UIViewController()

        view.rootViewController = pincodeController
    }

    func showPincodeSetup(on view: UIWindow) {
        guard let controller = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        view.rootViewController = controller
    }

    func showBroken(on view: UIWindow) {
        // normally user must not see this but on malicious devices it is possible
        view.backgroundColor = .red
    }
}
