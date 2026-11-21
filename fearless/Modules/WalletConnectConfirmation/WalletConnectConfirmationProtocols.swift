import SSFModels
import SSFUtils

typealias WalletConnectConfirmationModuleCreationResult = (
    view: WalletConnectConfirmationViewInput,
    input: WalletConnectConfirmationModuleInput
)

protocol WalletConnectConfirmationRouterInput: PresentDismissable, SheetAlertPresentable, ErrorPresentable {
    func showAllDone(
        chain: ChainModel,
        hashString: String?,
        view: ControllerBackedProtocol?,
        closure: @escaping () -> Void
    )
    func showRawData(json: JSON, from view: ControllerBackedProtocol?)
}

protocol WalletConnectConfirmationModuleInput: AnyObject {
    /// True while the confirmation signs: the PIN screen may be up.
    var isSigning: Bool { get }
}

protocol WalletConnectConfirmationModuleOutput: AnyObject {}
