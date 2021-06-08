import Foundation

class RecommendedValidatorListWireframe: RecommendedValidatorListWireframeProtocol {
    func proceed(
        from _: RecommendedValidatorListViewProtocol?,
        targets _: [SelectedValidatorInfo],
        maxTargets _: Int
    ) {}

    func present(
        _ validatorInfo: SelectedValidatorInfo,
        from view: RecommendedValidatorListViewProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(with: validatorInfo) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorInfoView.controller, animated: true)
    }
}
