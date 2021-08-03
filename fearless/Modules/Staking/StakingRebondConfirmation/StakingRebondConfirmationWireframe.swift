import Foundation

final class StakingRebondConfirmationWireframe: StakingRebondConfirmationWireframeProtocol, ModalAlertPresenting {
    func complete(from view: StakingRebondConfirmationViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: languages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
