import Foundation

final class SignerConfirmWireframe: SignerConfirmWireframeProtocol {
    func complete(on view: SignerConfirmViewProtocol?) {
        view?.controller.dismiss(animated: true, completion: nil)

        let title = R.string.localizable.commonTransactionSubmitted(preferredLanguages: view?.selectedLocale.rLanguages)
        presentSuccessNotification(
            title,
            from: view?.controller.navigationController?.presentingViewController,
            completion: nil
        )
    }
}
