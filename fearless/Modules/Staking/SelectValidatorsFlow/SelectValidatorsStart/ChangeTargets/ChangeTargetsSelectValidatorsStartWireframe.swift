import Foundation

final class ChangeTargetsSelectValidatorsStartWireframe: SelectValidatorsStartWireframe {
    private let state: ExistingBonding

    init(state: ExistingBonding) {
        self.state = state
    }

    override func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        validators: [ElectedValidatorInfo]
    ) {
        // TODO: https://soramitsu.atlassian.net/browse/FLW-891
        guard let nextView = CustomValidatorListViewFactory.createView(selectedValidators: validators) else { return }
        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }

    override func proceedToRecommendedList(
        from view: SelectValidatorsStartViewProtocol?,
        validators: [ElectedValidatorInfo],
        maxTargets: Int
    ) {
        let selectedValidators = validators.map {
            SelectedValidatorInfo(
                address: $0.address,
                identity: $0.identity,
                stakeInfo: ValidatorStakeInfo(
                    nominators: $0.nominators,
                    totalStake: $0.totalStake,
                    stakeReturn: $0.stakeReturn,
                    maxNominatorsRewarded: $0.maxNominatorsRewarded
                )
            )
        }

        guard let nextView = RecommendedValidatorListViewFactory.createChangeTargetsView(
            for: selectedValidators,
            maxTargets: maxTargets,
            with: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
