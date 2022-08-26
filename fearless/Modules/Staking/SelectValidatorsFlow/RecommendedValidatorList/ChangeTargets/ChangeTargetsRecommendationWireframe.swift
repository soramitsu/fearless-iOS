import Foundation

final class ChangeTargetsRecommendationWireframe: RecommendedValidatorListWireframe {
    override func proceed(
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
}
