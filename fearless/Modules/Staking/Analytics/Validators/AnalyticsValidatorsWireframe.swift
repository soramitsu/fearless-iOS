import Foundation

final class AnalyticsValidatorsWireframe: AnalyticsValidatorsWireframeProtocol {
    func showValidatorInfo(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        address: AccountAddress,
        view: ControllerBackedProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            address: address,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount
        ) else { return }
        let navigationController = FearlessNavigationController(rootViewController: validatorInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
