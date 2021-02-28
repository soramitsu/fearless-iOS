import Foundation

final class RecommendedValidatorsWireframe: RecommendedValidatorsWireframeProtocol {
    func proceed(from view: RecommendedValidatorsViewProtocol?, result: PreparedNomination) {
        // TODO: FLW-592
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
