import Foundation

class SelectValidatorsStartWireframe: SelectValidatorsStartWireframeProtocol {
    func proceedToCustomList(
        from _: ControllerBackedProtocol?,
        validatorList _: [SelectedValidatorInfo],
        recommendedValidatorList _: [SelectedValidatorInfo],
        selectedValidatorList _: SharedList<SelectedValidatorInfo>,
        maxTargets _: Int,
        asset _: AssetModel,
        chain _: ChainModel,
        selectedAccount _: MetaAccountModel
    ) {}

    func proceedToRecommendedList(
        from _: SelectValidatorsStartViewProtocol?,
        validatorList _: [SelectedValidatorInfo],
        maxTargets _: Int,
        selectedAccount _: MetaAccountModel,
        chain _: ChainModel,
        asset _: AssetModel
    ) {}
}
