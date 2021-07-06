import Foundation

class SelectValidatorsStartWireframe: SelectValidatorsStartWireframeProtocol {
    func proceedToCustomList(
        from _: ControllerBackedProtocol?,
        validatorList _: [SelectedValidatorInfo],
        recommendedValidatorList _: [SelectedValidatorInfo],
        maxTargets _: Int
    ) {}

    func proceedToRecommendedList(
        from _: SelectValidatorsStartViewProtocol?,
        validatorList _: [SelectedValidatorInfo],
        maxTargets _: Int
    ) {}
}
