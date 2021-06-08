import Foundation

final class SelectValidatorsWireframe: SelectValidatorsWireframeProtocol {
    func showValidatorInfo(
        from view: ControllerBackedProtocol?,
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
}
