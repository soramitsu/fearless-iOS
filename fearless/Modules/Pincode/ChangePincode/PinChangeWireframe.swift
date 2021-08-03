import Foundation
import SoraFoundation

final class PinChangeWireframe: PinSetupWireframeProtocol, ModalAlertPresenting {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func showMain(from view: PinSetupViewProtocol?) {
        let title = R.string.localizable
            .commonChanged(preferredLanguages: localizationManager.selectedLocale.rLanguages)

        presentSuccessNotification(title, from: view) {
            // Completion is called after viewDidAppear so we need to schedule transition to the next run loop
            DispatchQueue.main.async {
                view?.controller.navigationController?.popToRootViewController(animated: true)
            }
        }
    }

    func showSignup(from _: PinSetupViewProtocol?) {
        guard let signupViewController = OnboardingMainViewFactory.createViewForOnboarding()?.controller else {
            return
        }

        let rootAnimator = RootControllerAnimationCoordinator()

        rootAnimator.animateTransition(to: signupViewController)
    }
}
