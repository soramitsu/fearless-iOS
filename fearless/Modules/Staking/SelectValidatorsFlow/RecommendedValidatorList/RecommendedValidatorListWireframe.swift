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
        asset: AssetModel,
        chain: ChainModel,
        validatorInfo: SelectedValidatorInfo,
        from view: RecommendedValidatorListViewProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            asset: asset,
            chain: chain,
            validatorInfo: validatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorInfoView.controller, animated: true)
    }
}
