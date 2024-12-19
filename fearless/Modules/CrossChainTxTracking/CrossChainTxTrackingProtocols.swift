typealias CrossChainTxTrackingModuleCreationResult = (
    view: CrossChainTxTrackingViewInput,
    input: CrossChainTxTrackingModuleInput
)

protocol CrossChainTxTrackingRouterInput: AnyObject, AnyDismissable, ApplicationStatusPresentable, SharingPresentable {}

protocol CrossChainTxTrackingModuleInput: AnyObject {}

protocol CrossChainTxTrackingModuleOutput: AnyObject {}
