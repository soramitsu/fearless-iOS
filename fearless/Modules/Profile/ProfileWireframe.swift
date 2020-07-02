import Foundation
import UIKit

final class ProfileWireframe: ProfileWireframeProtocol, AuthorizationPresentable {
    func showPersonalDetailsView(from view: ProfileViewProtocol?) {

    }

    func showPassphraseView(from view: ProfileViewProtocol?) {
        authorize(animated: true, cancellable: true) { (isAuthorized) in
            if isAuthorized {
            }
        }
    }

    func showLanguageSelection(from view: ProfileViewProtocol?) {

    }

    func showAbout(from view: ProfileViewProtocol?) {}
}
