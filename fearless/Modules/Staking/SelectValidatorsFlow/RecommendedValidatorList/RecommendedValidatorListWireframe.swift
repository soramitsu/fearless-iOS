import Foundation

class RecommendedValidatorListWireframe: RecommendedValidatorListWireframeProtocol {
    func proceed(
        from _: RecommendedValidatorListViewProtocol?,
        flow _: SelectValidatorsConfirmFlow,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset
    ) {}

    func present(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: RecommendedValidatorListViewProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorInfoView.controller, animated: true)
    }
}
