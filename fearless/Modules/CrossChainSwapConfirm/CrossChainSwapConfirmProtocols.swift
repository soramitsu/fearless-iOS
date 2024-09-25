typealias CrossChainSwapConfirmModuleCreationResult = (
    view: CrossChainSwapConfirmViewInput,
    input: CrossChainSwapConfirmModuleInput
)

protocol CrossChainSwapConfirmRouterInput: AnyObject, PresentDismissable, SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable, AllDonePresentable {}

protocol CrossChainSwapConfirmModuleInput: AnyObject {}

protocol CrossChainSwapConfirmModuleOutput: AnyObject {}
