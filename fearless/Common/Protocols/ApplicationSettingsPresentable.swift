import Foundation
import UIKit

protocol ApplicationSettingsPresentable {
    func askOpenApplicationSettings(
        with message: String,
        title: String?,
        from view: ControllerBackedProtocol?
    )
}

extension ApplicationSettingsPresentable {
    func askOpenApplicationSettings(
        with message: String,
        title: String?,
        from view: ControllerBackedProtocol?
    ) {
        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let closeAction = UIAlertAction(title: L10n.Common.notNow, style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: L10n.Common.openSettings, style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            }
        }

        alert.addAction(closeAction)
        alert.addAction(settingsAction)

        controller.present(alert, animated: true, completion: nil)
    }
}
