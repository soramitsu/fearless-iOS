import Foundation

final class InitBondingSelectValidatorsStartWireframe: SelectValidatorsStartWireframe {
    override func proceedToCustomList(from view: ControllerBackedProtocol?, flow: CustomValidatorListFlow, chainAsset: ChainAsset, wallet: MetaAccountModel) {
        guard let nextView = CustomValidatorListViewFactory.createInitiatedBondingView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }

    override func proceedToRecommendedList(
        from view: SelectValidatorsStartViewProtocol?,
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        guard let nextView = RecommendedValidatorListViewFactory.createInitiatedBondingView(
            flow: flow,
            wallet: wallet,
            chainAsset: chainAsset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
