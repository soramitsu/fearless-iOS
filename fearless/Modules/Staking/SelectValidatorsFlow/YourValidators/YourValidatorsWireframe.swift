import Foundation

final class YourValidatorsWireframe: YourValidatorsWireframeProtocol {
    func showValidatorInfo(
        from view: YourValidatorsViewProtocol?,
        validatorInfo: ValidatorInfoProtocol
    ) {
        guard
            let validatorInfoView = ValidatorInfoViewFactory
            .createView(with: validatorInfo) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorInfoView.controller,
            animated: true
        )
    }

    func proceedToSelectValidatorsStart(
        from view: YourValidatorsViewProtocol?,
        existingBonding: ExistingBonding
    ) {
        guard let nextView = SelectValidatorsStartViewFactory
            .createChangeYourValidatorsView(with: existingBonding) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
