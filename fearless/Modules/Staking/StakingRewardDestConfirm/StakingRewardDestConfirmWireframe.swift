import Foundation

final class StakingRewardDestConfirmWireframe: StakingRewardDestConfirmWireframeProtocol, ModalAlertPresenting {
    func complete(from view: StakingRewardDestConfirmViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: languages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
