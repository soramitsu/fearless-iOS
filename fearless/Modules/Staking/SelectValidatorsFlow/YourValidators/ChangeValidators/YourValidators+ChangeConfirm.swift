import Foundation

extension YourValidators {
    final class StakingConfirmWireframe: StakingConfirmWireframeProtocol, ModalAlertPresenting {
        func complete(from view: StakingConfirmViewProtocol?) {
            let languages = view?.localizationManager?.selectedLocale.rLanguages
            let title = R.string.localizable
                .commonTransactionSubmitted(preferredLanguages: languages)

            let navigationController = view?.controller.navigationController
            navigationController?.popToRootViewController(animated: true)
            presentSuccessNotification(title, from: navigationController, completion: nil)
        }
    }
}
