import Foundation

class SelectValidatorsStartWireframe: SelectValidatorsStartWireframeProtocol {
    func proceedToCustomList(
        from _: ControllerBackedProtocol?,
        flow _: CustomValidatorListFlow,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {}

    func proceedToRecommendedList(
        from _: SelectValidatorsStartViewProtocol?,
        flow _: RecommendedValidatorListFlow,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset
    ) {}
}
