import Foundation
import UIKit
import SoraFoundation

extension UIAlertController {
    static func phishingWarningAlert(onConfirm: @escaping () -> Void,
                                     onCancel: @escaping () -> Void,
                                     locale: Locale,
                                     publicKey paramValue: String) -> UIAlertController {
        let title = R.string.localizable
            .walletSendPhishingWarningTitle(preferredLanguages: locale.rLanguages)

        let message = R.string.localizable
            .walletSendPhishingWarningText(paramValue, preferredLanguages: locale.rLanguages)

        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let proceedTitle = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        let proceedAction = UIAlertAction(title: proceedTitle, style: .default) { _ in onConfirm() }
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in onCancel() }

        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        alertController.addAction(proceedAction)
        alertController.addAction(cancelAction)

        return alertController
    }
}
