typealias CrossChainTxTrackingModuleCreationResult = (
    view: CrossChainTxTrackingViewInput,
    input: CrossChainTxTrackingModuleInput
)

protocol CrossChainTxTrackingRouterInput: AnyObject, AnyDismissable {}

protocol CrossChainTxTrackingModuleInput: AnyObject {}

protocol CrossChainTxTrackingModuleOutput: AnyObject {}
