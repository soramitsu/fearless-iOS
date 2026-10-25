
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
    /// Shows the submitted transfer with its hash; `title` and `description` say that the bridge still has to deliver it.
    func complete(
        on view: ControllerBackedProtocol?,
        hash: String?,
        title: String,
        description: String,
        chainAsset: ChainAsset
    )
}

protocol CrossChainConfirmationModuleInput: AnyObject {}

protocol CrossChainConfirmationModuleOutput: AnyObject {}
