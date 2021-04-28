import Foundation

extension YourValidators {
    final class StakingConfirmWireframe: StakingConfirmWireframeProtocol, ModalAlertPresenting {
        func complete(from view: StakingConfirmViewProtocol?) {
            let languages = view?.localizationManager?.selectedLocale.rLanguages
            let title = R.string.localizable
                .stakingSetupSentMessage(preferredLanguages: languages)

            let navigationController = view?.controller.navigationController
            navigationController?.popToRootViewController(animated: true)
            presentSuccessNotification(title, from: navigationController, completion: nil)
        }

        func showSelectedValidator(
            from view: StakingConfirmViewProtocol?,
            validators: [SelectedValidatorInfo],
            maxTargets: Int
        ) {
            guard let validatorsView = SelectedValidatorsViewFactory
                .createView(for: validators, maxTargets: maxTargets)
            else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                validatorsView.controller,
                animated: true
            )
        }
    }
}
