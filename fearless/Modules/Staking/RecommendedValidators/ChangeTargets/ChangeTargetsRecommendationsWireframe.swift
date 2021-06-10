import Foundation

final class ChangeTargetsRecommendationsWireframe: RecommendedValidatorsWireframe {
    private let state: ExistingBonding

    init(state: ExistingBonding) {
        self.state = state
    }

    override func proceedToCustomList(
        from _: ControllerBackedProtocol?,
        validators _: [ElectedValidatorInfo]
    ) {
        // TODO: https://soramitsu.atlassian.net/browse/FLW-891
    }

    override func proceedToRecommendedList(
        from view: RecommendedValidatorsViewProtocol?,
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

        guard let nextView = SelectedValidatorsViewFactory.createChangeTargetsView(
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
