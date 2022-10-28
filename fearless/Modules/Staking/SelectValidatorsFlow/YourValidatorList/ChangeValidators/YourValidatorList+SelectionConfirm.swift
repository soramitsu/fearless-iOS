import Foundation

extension YourValidatorList {
    final class SelectValidatorsConfirmWireframe: SelectValidatorsConfirmWireframeProtocol, ModalAlertPresenting {
        func complete(from view: SelectValidatorsConfirmViewProtocol?) {
            let languages = view?.localizationManager?.selectedLocale.rLanguages
            let title = R.string.localizable
                .commonTransactionSubmitted(preferredLanguages: languages)

            let navigationController = view?.controller.navigationController
            let presentingViewCotroller = navigationController?.presentingViewController
            navigationController?.dismiss(animated: true)
            presentSuccessNotification(title, from: presentingViewCotroller, completion: nil)
        }
    }
}
