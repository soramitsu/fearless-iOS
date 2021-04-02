import Foundation

final class SelectedValidatorsWireframe: SelectedValidatorsWireframeProtocol {
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
