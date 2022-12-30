import Foundation

class RecommendedValidatorListWireframe: RecommendedValidatorListWireframeProtocol {
    func proceed(
        from view: RecommendedValidatorListViewProtocol?,
        flow: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        guard let confirmView = SelectValidatorsConfirmViewFactory.createView(
            chainAsset: chainAsset,
            flow: flow,
            wallet: wallet
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }

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
