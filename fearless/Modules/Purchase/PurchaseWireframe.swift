import Foundation

import SoraFoundation

final class PurchaseWireframe: PurchaseWireframeProtocol {
    let localizationManager: LocalizationManagerProtocol

    init(
        localizationManager: LocalizationManagerProtocol
    ) {
        self.localizationManager = localizationManager
    }

    func complete(from view: PurchaseViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.presentPurchaseCompletion(from: view)
            }
        }
    }

    private func presentPurchaseCompletion(from view: ControllerBackedProtocol?) {
        let languages = localizationManager.selectedLocale.rLanguages
        let message = R.string.localizable
            .buyCompleted(preferredLanguages: languages)

        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true, completion: nil)
    }
}
