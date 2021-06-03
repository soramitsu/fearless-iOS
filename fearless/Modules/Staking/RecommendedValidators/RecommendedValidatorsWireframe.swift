import Foundation

class RecommendedValidatorsWireframe: RecommendedValidatorsWireframeProtocol {
    func proceedToCustomList(
        from _: ControllerBackedProtocol?,
        validators _: [ElectedValidatorInfo]
    ) {}

    func proceedToRecommendedList(
        from _: RecommendedValidatorsViewProtocol?,
        validators _: [ElectedValidatorInfo],
        maxTargets _: Int
    ) {}
}
