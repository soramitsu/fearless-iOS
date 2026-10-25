typealias MultichainAssetSelectionModuleCreationResult = (
    view: MultichainAssetSelectionViewInput,
    input: MultichainAssetSelectionModuleInput
)

protocol MultichainAssetSelectionRouterInput: AnyObject, AnyDismissable {}

protocol MultichainAssetSelectionModuleInput: AnyObject {}

protocol MultichainAssetSelectionModuleOutput: AnyObject {}
