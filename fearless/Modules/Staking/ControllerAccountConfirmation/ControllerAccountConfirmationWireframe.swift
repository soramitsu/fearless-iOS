import Foundation

final class ControllerAccountConfirmationWireframe: ControllerAccountConfirmationWireframeProtocol,
    ModalAlertPresenting {
    func complete(from view: ControllerAccountConfirmationViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .stakingBondMoreCompletion(preferredLanguages: languages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
