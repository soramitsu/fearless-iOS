import Foundation

final class YourValidatorListWireframe: YourValidatorListWireframeProtocol {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: YourValidatorListViewProtocol?
    ) {
        guard
            let nextView = ValidatorInfoViewFactory
            .createView(with: validatorInfo) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }

    func proceedToSelectValidatorsStart(
        from view: YourValidatorListViewProtocol?,
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
