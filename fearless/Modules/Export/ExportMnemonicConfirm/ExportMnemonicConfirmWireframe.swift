import Foundation
import SoraFoundation

final class ExportMnemonicConfirmWireframe: AccountConfirmWireframeProtocol, ModalAlertPresenting {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func proceed(from view: AccountConfirmViewProtocol?) {
        let title = R.string.localizable
            .commonConfirmed(preferredLanguages: localizationManager.selectedLocale.rLanguages)

        presentSuccessNotification(title, from: view) {
            DispatchQueue.main.async {
                view?.controller.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
}
