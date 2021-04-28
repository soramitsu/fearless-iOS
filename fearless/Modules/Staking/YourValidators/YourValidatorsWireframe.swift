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

    func showRecommendedValidators(
        from view: YourValidatorsViewProtocol?,
        existingBonding: ExistingBonding
    ) {
        guard let recommendedValidatorsView = RecommendedValidatorsViewFactory
            .createChangeYourValidatorsView(with: existingBonding) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            recommendedValidatorsView.controller,
            animated: true
        )
    }
}
