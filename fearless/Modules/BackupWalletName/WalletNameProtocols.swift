typealias WalletNameModuleCreationResult = (
    view: WalletNameViewInput,
    input: WalletNameModuleInput
)

protocol WalletNameRouterInput: AnyDismissable, SheetAlertPresentable, ErrorPresentable {
    func showWarningsScreen(
        walletName: String,
        from view: ControllerBackedProtocol?
    )
    func complete()
}

protocol WalletNameModuleInput: AnyObject {}

protocol WalletNameModuleOutput: AnyObject {}
