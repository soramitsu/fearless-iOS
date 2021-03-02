import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showSetupAmount(from view: StakingMainViewProtocol?) {
        guard let amountView = StakingAmountViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: amountView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func presentNotEnoughFunds(from view: StakingMainViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let message = R.string.localizable
            .stakingAmountTooBigError(preferredLanguages: languages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: languages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
