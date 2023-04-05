typealias CrossChainConfirmationModuleCreationResult = (
    view: CrossChainConfirmationViewInput,
    input: CrossChainConfirmationModuleInput
)

protocol CrossChainConfirmationRouterInput: PresentDismissable {}

protocol CrossChainConfirmationModuleInput: AnyObject {}

protocol CrossChainConfirmationModuleOutput: AnyObject {}
