typealias WalletConnectSessionModuleCreationResult = (
    view: WalletConnectSessionViewInput,
    input: WalletConnectSessionModuleInput
)

protocol WalletConnectSessionRouterInput: AnyDismissable, SheetAlertPresentable, ModalAlertPresenting, HiddableBarWhenPushed {
    func showConfirmation(inputData: WalletConnectConfirmationInputData)
}

protocol WalletConnectSessionModuleInput: AnyObject {}

protocol WalletConnectSessionModuleOutput: AnyObject {}
