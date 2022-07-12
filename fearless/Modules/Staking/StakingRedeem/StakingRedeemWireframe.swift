import Foundation

final class StakingRedeemWireframe: StakingRedeemWireframeProtocol, ModalAlertPresenting {
    private let redeemCompletion: (() -> Void)?

    init(redeemCompletion: (() -> Void)?) {
        self.redeemCompletion = redeemCompletion
    }

    func complete(from view: StakingRedeemViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: languages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.redeemCompletion?()
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
