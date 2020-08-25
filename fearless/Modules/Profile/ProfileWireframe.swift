import Foundation
import UIKit

final class ProfileWireframe: ProfileWireframeProtocol, AuthorizationPresentable {
    func showAccountDetails(from view: ProfileViewProtocol?) {}

    func showPincodeChange(from view: ProfileViewProtocol?) {}

    func showAccountSelection(from view: ProfileViewProtocol?) {}

    func showConnectionSelection(from view: ProfileViewProtocol?) {
        guard let nodeSelection = NodeSelectionViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            nodeSelection.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(nodeSelection.controller, animated: true)
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
}
