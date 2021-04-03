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
                    stakeReturn: $0.stakeReturn
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
        from _: RecommendedValidatorsViewProtocol?,
        validators _: [ElectedValidatorInfo]
    ) {
        // TODO: FLW-593
    }
}
