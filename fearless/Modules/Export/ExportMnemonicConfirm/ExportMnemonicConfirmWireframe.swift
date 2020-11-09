import Foundation
import SoraFoundation

final class ExportMnemonicConfirmWireframe: AccountConfirmWireframeProtocol, ModalAlertPresenting {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func proceed(from view: AccountConfirmViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
