import Foundation

final class ChangeTargetsRecommendationWireframe: RecommendedValidatorListWireframe {
    let state: ExistingBonding

    init(state: ExistingBonding) {
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

        guard let confirmView = SelectValidatorsConfirmViewFactory.createChangeTargetsView(
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
