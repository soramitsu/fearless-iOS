final class StakingBondMoreConfirmationWireframe: StakingBondMoreConfirmationWireframeProtocol,
    ModalAlertPresenting {
    func complete(from view: StakingBondMoreConfirmationViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .stakingBondMoreCompletion(preferredLanguages: languages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
