import Foundation

class RecommendedValidatorListWireframe: RecommendedValidatorListWireframeProtocol {
    func proceed(
        from _: RecommendedValidatorListViewProtocol?,
        targets _: [SelectedValidatorInfo],
        maxTargets _: Int,
        selectedAccount _: MetaAccountModel,
        asset _: AssetModel,
        chain _: ChainModel
    ) {}

    func present(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: RecommendedValidatorListViewProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(chainAsset: chainAsset, wallet: wallet, flow: flow) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorInfoView.controller, animated: true)
    }
}
