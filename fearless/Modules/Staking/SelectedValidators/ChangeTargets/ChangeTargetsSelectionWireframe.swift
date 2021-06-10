import Foundation

final class ChangeTargetsSelectionWireframe: SelectedValidatorsWireframe {
    let state: ExistingBonding

    init(state: ExistingBonding) {
        self.state = state
    }

    override func proceed(
        from view: SelectedValidatorsViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int
    ) {
        let nomination = PreparedNomination(
            bonding: state,
            targets: targets,
            maxTargets: maxTargets
        )

        guard let confirmView = StakingConfirmViewFactory.createChangeTargetsView(for: nomination) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
