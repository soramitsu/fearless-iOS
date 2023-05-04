typealias CrossChainConfirmationModuleCreationResult = (
    view: CrossChainConfirmationViewInput,
    input: CrossChainConfirmationModuleInput
)

protocol CrossChainConfirmationRouterInput:
    PresentDismissable,
    ErrorPresentable,
    BaseErrorPresentable,
    ModalAlertPresenting,
    SheetAlertPresentable {
    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset: ChainAsset
    )
}

protocol CrossChainConfirmationModuleInput: AnyObject {}

protocol CrossChainConfirmationModuleOutput: AnyObject {}
