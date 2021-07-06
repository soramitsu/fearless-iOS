import Foundation

extension YourValidatorList {
    final class SelectValidatorsConfirmWireframe: SelectValidatorsConfirmWireframeProtocol, ModalAlertPresenting {
        func complete(from view: SelectValidatorsConfirmViewProtocol?) {
            let languages = view?.localizationManager?.selectedLocale.rLanguages
            let title = R.string.localizable
                .commonTransactionSubmitted(preferredLanguages: languages)

            let navigationController = view?.controller.navigationController
            navigationController?.popToRootViewController(animated: true)
            presentSuccessNotification(title, from: navigationController, completion: nil)
        }
    }
}
