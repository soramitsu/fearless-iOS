import Foundation

final class InitiatedBondingRecommendationsWireframe: RecommendedValidatorsWireframe {
    private let state: InitiatedBonding

    init(state: InitiatedBonding) {
        self.state = state
    }

    override func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        validators: [ElectedValidatorInfo]
    ) {
        // TODO: https://soramitsu.atlassian.net/browse/FLW-891
        let optSelectValidators = SelectValidatorsViewFactory.createView(selectedValidators: validators)
        guard let selectValidators = optSelectValidators else { return }
        view?.controller.navigationController?.pushViewController(
            selectValidators.controller,
            animated: true
        )
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

        guard let nextView = SelectedValidatorsViewFactory.createInitiatedBondingView(
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
