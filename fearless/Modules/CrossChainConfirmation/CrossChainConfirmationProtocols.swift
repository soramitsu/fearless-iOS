
import SSFModels
typealias CrossChainConfirmationModuleCreationResult = (
    view: CrossChainConfirmationViewInput,
    input: CrossChainConfirmationModuleInput
)

protocol CrossChainConfirmationRouterInput:
    PushDismissable,
    ErrorPresentable,
    BaseErrorPresentable,
    ModalAlertPresenting,
    SheetAlertPresentable
{
    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset: ChainAsset
    )
}

protocol CrossChainConfirmationModuleInput: AnyObject {}

protocol CrossChainConfirmationModuleOutput: AnyObject {}
