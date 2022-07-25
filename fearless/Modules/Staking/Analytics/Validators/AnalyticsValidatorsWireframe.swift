import Foundation

final class AnalyticsValidatorsWireframe: AnalyticsValidatorsWireframeProtocol {
    func showValidatorInfo(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: ValidatorInfoFlow,
        view: ControllerBackedProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(chainAsset: chainAsset, wallet: wallet, flow: flow) else { return }
        let navigationController = FearlessNavigationController(rootViewController: validatorInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
