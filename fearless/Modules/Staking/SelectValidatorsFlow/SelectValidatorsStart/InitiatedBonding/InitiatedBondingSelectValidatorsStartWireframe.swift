import Foundation

final class InitiatedBondingSelectValidatorsStartWireframe: SelectValidatorsStartWireframe {
    private let state: InitiatedBonding

    init(state: InitiatedBonding) {
        self.state = state
    }

    override func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        validators: [ElectedValidatorInfo],
        recommended: [ElectedValidatorInfo],
        maxTargets: Int
    ) {
        // TODO: https://soramitsu.atlassian.net/browse/FLW-891
        guard let nextView = CustomValidatorListViewFactory.createView(
            electedValidators: validators,
            recommendedValidators: recommended,
            maxTargets: maxTargets
        ) else { return }

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

        guard let nextView = RecommendedValidatorListViewFactory.createInitiatedBondingView(
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
