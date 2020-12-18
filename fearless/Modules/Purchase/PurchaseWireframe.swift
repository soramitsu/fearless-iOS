import Foundation
import CommonWallet
import SoraFoundation

final class PurchaseWireframe: PurchaseWireframeProtocol {
    let commandFactory: WalletCommandFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol,
         commandFactory: WalletCommandFactoryProtocol) {
        self.localizationManager = localizationManager
        self.commandFactory = commandFactory
    }

    func complete(from view: PurchaseViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.presentPurchaseCompletion()
            }
        }
    }

    private func presentPurchaseCompletion() {
        let languages = localizationManager.selectedLocale.rLanguages
        let message = R.string.localizable
            .buyCompleted(preferredLanguages: languages)

        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        let command = commandFactory.preparePresentationCommand(for: alertController)
        command.presentationStyle = .modal(inNavigation: false)

        try? command.execute()
    }
}
