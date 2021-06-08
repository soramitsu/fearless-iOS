import Foundation

extension YourValidators {
    final class RecommendationsWireframe: RecommendedValidatorsWireframe {
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

            guard let nextView = SelectedValidatorsViewFactory.createChangeYourValidatorsView(
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

    final class SelectionWireframe: SelectedValidatorsWireframe {
        private let state: ExistingBonding

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

            guard let confirmView = StakingConfirmViewFactory
                .createChangeYourValidatorsView(for: nomination) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                confirmView.controller,
                animated: true
            )
        }
    }
}
