import Foundation

final class CrowdloanContributionConfirmWireframe: CrowdloanContributionConfirmWireframeProtocol, ModalAlertPresenting {
    func complete(on view: CrowdloanContributionConfirmViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: languages)

        let presenter = view?.controller.navigationController
        view?.controller.navigationController?.popToRootViewController(animated: true)

        presentSuccessNotification(title, from: presenter, completion: nil)
    }
}
