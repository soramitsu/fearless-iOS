import Foundation

final class InitiatedBondingRecommendationWireframe: RecommendedValidatorListWireframe {
    let state: InitiatedBonding

    init(state: InitiatedBonding) {
        self.state = state
    }

    override func proceed(
        from view: RecommendedValidatorListViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int,
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel
    ) {
        let nomination = PreparedNomination(
            bonding: state,
            targets: targets,
            maxTargets: maxTargets
        )

        guard let confirmView = SelectValidatorsConfirmViewFactory.createInitiatedBondingView(
            selectedAccount: selectedAccount,
            asset: asset,
            chain: chain,
            for: nomination
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
