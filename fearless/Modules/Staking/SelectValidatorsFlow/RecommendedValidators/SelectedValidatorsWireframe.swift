import Foundation

class SelectedValidatorsWireframe: SelectedValidatorsWireframeProtocol {
    func proceed(
        from _: SelectedValidatorsViewProtocol?,
        targets _: [SelectedValidatorInfo],
        maxTargets _: Int
    ) {}

    func showInformation(
        about validatorInfo: SelectedValidatorInfo,
        from view: SelectedValidatorsViewProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(with: validatorInfo) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorInfoView.controller, animated: true)
    }
}
