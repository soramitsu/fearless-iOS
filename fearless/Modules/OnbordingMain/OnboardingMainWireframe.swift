import Foundation

final class OnboardingMainWireframe: OnboardingMainWireframeProtocol {
    func showSignup(from view: OnboardingMainViewProtocol?) {
        guard let accessBackup = AccessBackupViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(accessBackup.controller, animated: true)
        }
    }

    func showAccountRestore(from view: OnboardingMainViewProtocol?) {
        guard let restorationController = AccessRestoreViewFactory.createView()?.controller else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(restorationController, animated: true)
        }
    }
}
