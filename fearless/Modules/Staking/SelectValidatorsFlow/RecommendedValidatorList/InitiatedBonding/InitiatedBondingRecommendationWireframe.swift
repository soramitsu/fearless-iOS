import Foundation

final class InitiatedBondingRecommendationWireframe: RecommendedValidatorListWireframe {
    let state: InitiatedBonding

    init(state: InitiatedBonding) {
        self.state = state
    }

    override func proceed(
        from view: RecommendedValidatorListViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int
    ) {
        let nomination = PreparedNomination(
            bonding: state,
            targets: targets,
            maxTargets: maxTargets
        )

        guard let confirmView = SelectValidatorsConfirmViewFactory.createInitiatedBondingView(for: nomination) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
