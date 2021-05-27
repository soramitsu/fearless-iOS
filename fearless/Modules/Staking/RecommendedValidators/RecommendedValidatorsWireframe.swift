import Foundation

class RecommendedValidatorsWireframe: RecommendedValidatorsWireframeProtocol {
    func proceed(
        from _: RecommendedValidatorsViewProtocol?,
        targets _: [SelectedValidatorInfo],
        maxTargets _: Int
    ) {}

    func showRecommended(
        from view: RecommendedValidatorsViewProtocol?,
        validators: [ElectedValidatorInfo],
        maxTargets: Int
    ) {
        let selected = validators.map {
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

        guard let validatorsView = SelectedValidatorsViewFactory.createView(
            for: selected,
            maxTargets: maxTargets
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorsView.controller,
            animated: true
        )
    }

    func showCustom(
        from view: ControllerBackedProtocol?,
        validators: [ElectedValidatorInfo]
    ) {
        let optSelectValidators = SelectValidatorsViewFactory.createView(selectedValidators: validators)
        guard let selectValidators = optSelectValidators else { return }
        view?.controller.navigationController?.pushViewController(
            selectValidators.controller,
            animated: true
        )
    }
}
