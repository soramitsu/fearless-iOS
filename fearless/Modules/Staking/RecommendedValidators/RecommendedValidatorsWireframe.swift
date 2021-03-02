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
        // TODO: FLW-590
    }

    func showCustom(from view: RecommendedValidatorsViewProtocol?,
                    validators: [ElectedValidatorInfo]) {
        // TODO: FLW-593
    }
}
