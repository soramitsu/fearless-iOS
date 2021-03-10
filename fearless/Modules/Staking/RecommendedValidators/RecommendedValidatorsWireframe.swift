import Foundation

final class RecommendedValidatorsWireframe: RecommendedValidatorsWireframeProtocol {
    func proceed(from view: RecommendedValidatorsViewProtocol?, result: PreparedNomination) {
        guard let confirmView = StakingConfirmViewFactory.createView(for: result) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller,
                                                                  animated: true)
    }

    func showRecommended(from view: RecommendedValidatorsViewProtocol?,
                         validators: [ElectedValidatorInfo]) {
        let selected = validators.map {
            SelectedValidatorInfo(address: $0.address,
                                  identity: $0.identity,
                                  stakeInfo: ValidatorStakeInfo(nominators: $0.nominators,
                                                                totalStake: $0.totalStake,
                                                                stakeReturn: $0.stakeReturn)) }

        guard let validatorsView = SelectedValidatorsViewFactory.createView(for: selected) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorsView.controller,
                                                                  animated: true)
    }

    func showCustom(from view: RecommendedValidatorsViewProtocol?,
                    validators: [ElectedValidatorInfo]) {
        // TODO: FLW-593
    }
}
