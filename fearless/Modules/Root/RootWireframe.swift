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

    func showVersionUnsupported(from view: ControllerBackedProtocol?, locale: Locale) {
        let alert = UIAlertController(
            title: R.string.localizable.appVersionUnsupportedText(preferredLanguages: locale.rLanguages),
            message: nil,
            preferredStyle: .alert
        )
        let updateAction = UIAlertAction(
            title: R.string.localizable.commonUpdate(preferredLanguages: locale.rLanguages),
            style: .default
        ) { _ in
            if let url = URL(string: URLConstants.appstoreLink) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        alert.addAction(updateAction)

        view?.controller.present(alert, animated: true, completion: nil)
    }
}
