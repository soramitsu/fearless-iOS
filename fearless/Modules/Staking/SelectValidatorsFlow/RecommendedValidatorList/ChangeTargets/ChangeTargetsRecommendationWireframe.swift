import Foundation

final class ChangeTargetsRecommendationWireframe: RecommendedValidatorListWireframe {
    override func proceed(
        from view: RecommendedValidatorListViewProtocol?,
        flow: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        guard let confirmView = SelectValidatorsConfirmViewFactory.createChangeTargetsView(
            wallet: wallet,
            chainAsset: chainAsset,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
