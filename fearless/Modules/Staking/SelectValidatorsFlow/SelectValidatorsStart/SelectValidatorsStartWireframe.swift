import Foundation

class SelectValidatorsStartWireframe: SelectValidatorsStartWireframeProtocol {
    func proceedToCustomList(
        from _: ControllerBackedProtocol?,
        validators _: [ElectedValidatorInfo],
        maxTargets _: Int
    ) {}

    func proceedToRecommendedList(
        from _: SelectValidatorsStartViewProtocol?,
        validators _: [ElectedValidatorInfo],
        maxTargets _: Int
    ) {}
}
