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
        window.backgroundColor = .red
    }

    func showVersionUnsupported(from view: ControllerBackedProtocol?) {
        let alert = UIAlertController(title: "Please update app", message: "This version is unsupported", preferredStyle: .alert)
        let updateAction = UIAlertAction(title: "Go appstore", style: .default) { _ in
            if let url = URL(string: "itms-apps://apple.com/app/id1537251089") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        alert.addAction(updateAction)

        view?.controller.present(alert, animated: true, completion: nil)
    }
}
