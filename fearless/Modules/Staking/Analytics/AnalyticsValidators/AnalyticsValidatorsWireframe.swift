import Foundation

final class AnalyticsValidatorsWireframe: AnalyticsValidatorsWireframeProtocol {
    func showValidatorInfo(address: AccountAddress, view: ControllerBackedProtocol?) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(with: address) else { return }
        let navigationController = FearlessNavigationController(rootViewController: validatorInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
