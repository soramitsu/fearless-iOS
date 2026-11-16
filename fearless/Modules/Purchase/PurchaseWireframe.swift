import UIKit

import SoraFoundation

final class PurchaseWireframe: PurchaseWireframeProtocol {
    let localizationManager: LocalizationManagerProtocol

    init(
        localizationManager: LocalizationManagerProtocol
    ) {
        self.localizationManager = localizationManager
    }

    func complete(from view: PurchaseViewProtocol?) {
        // The purchase page is dismissed, so the screen that opened it shows the alert.
        guard let presentingController = view?.controller.presentingViewController else {
            return
        }

        presentingController.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.presentPurchaseCompletion(from: presentingController)
            }
        }
    }

    private func presentPurchaseCompletion(from controller: UIViewController) {
        let languages = localizationManager.selectedLocale.rLanguages
        let message = R.string.localizable
            .buyCompleted(preferredLanguages: languages)

        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        controller.present(alertController, animated: true, completion: nil)
    }
}
