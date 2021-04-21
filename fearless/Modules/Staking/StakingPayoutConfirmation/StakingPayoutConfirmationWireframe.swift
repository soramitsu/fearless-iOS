import Foundation

final class StakingPayoutConfirmationWireframe: StakingPayoutConfirmationWireframeProtocol, ModalAlertPresenting {
    func complete(from view: StakingPayoutConfirmationViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .stakingSetupSentMessage(preferredLanguages: languages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
