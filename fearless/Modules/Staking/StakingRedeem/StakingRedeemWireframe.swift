import Foundation

final class StakingRedeemWireframe: StakingRedeemWireframeProtocol, ModalAlertPresenting {
    func complete(from view: StakingRedeemViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .stakingUnbondCompletionMessage(preferredLanguages: languages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
