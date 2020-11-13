import Foundation
import UIKit

final class ProfileWireframe: ProfileWireframeProtocol, AuthorizationPresentable {
    func showAccountDetails(from view: ProfileViewProtocol?) {
        guard let accountManagement = AccountManagementViewFactory.createView() else {
            return
        }

        accountManagement.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(accountManagement.controller,
                                                                  animated: true)
    }

    func showPincodeChange(from view: ProfileViewProtocol?) {
        authorize(animated: true, cancellable: true) { [weak self] (completed) in
            if completed {
                self?.showPinSetup(from: view)
            }
        }
    }

    func showAccountSelection(from view: ProfileViewProtocol?) {
        guard let accountManagement = AccountManagementViewFactory.createView() else {
            return
        }

        accountManagement.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(accountManagement.controller,
                                                                  animated: true)
    }

    func showConnectionSelection(from view: ProfileViewProtocol?) {
        guard let networkManagement = NetworkManagementViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            networkManagement.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(networkManagement.controller, animated: true)
        }
    }

    func showLanguageSelection(from view: ProfileViewProtocol?) {
        guard let languageSelection = LanguageSelectionViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            languageSelection.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(languageSelection.controller, animated: true)
        }
    }

    func showAbout(from view: ProfileViewProtocol?) {
        guard let aboutView = AboutViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            aboutView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(aboutView.controller, animated: true)
        }
    }

    // MARK: Private

    private func showPinSetup(from view: ProfileViewProtocol?) {
        guard let pinSetup = PinViewFactory.createPinChangeView() else {
            return
        }

        pinSetup.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(pinSetup.controller,
                                                                  animated: true)
    }
}
