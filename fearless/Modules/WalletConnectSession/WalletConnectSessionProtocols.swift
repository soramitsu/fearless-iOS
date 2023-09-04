typealias WalletConnectSessionModuleCreationResult = (
    view: WalletConnectSessionViewInput,
    input: WalletConnectSessionModuleInput
)

protocol WalletConnectSessionRouterInput: AnyDismissable, SheetAlertPresentable, ModalAlertPresenting, HiddableBarWhenPushed {
    func showAllDone(
        title: String,
        description: String,
        view: ControllerBackedProtocol?,
        closure: @escaping () -> Void
    )
    func showConfirmation(
        inputData: WalletConnectConfirmationInputData,
        from view: ControllerBackedProtocol?
    )
}

protocol WalletConnectSessionModuleInput: AnyObject {}

protocol WalletConnectSessionModuleOutput: AnyObject {}
