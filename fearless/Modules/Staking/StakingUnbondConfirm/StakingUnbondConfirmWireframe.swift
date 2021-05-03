import Foundation

final class StakingUnbondConfirmWireframe: StakingUnbondConfirmWireframeProtocol, ModalAlertPresenting {
    func complete(from view: StakingUnbondConfirmViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .stakingSetupSentMessage(preferredLanguages: languages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
