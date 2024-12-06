typealias CrossChainSwapConfirmModuleCreationResult = (
    view: CrossChainSwapConfirmViewInput,
    input: CrossChainSwapConfirmModuleInput
)

protocol CrossChainSwapConfirmRouterInput: AnyObject, PushDismissable, SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable, AllDonePresentable {}

protocol CrossChainSwapConfirmModuleInput: AnyObject {}

protocol CrossChainSwapConfirmModuleOutput: AnyObject {}
