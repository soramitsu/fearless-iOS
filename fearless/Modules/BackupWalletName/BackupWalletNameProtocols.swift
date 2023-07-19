typealias BackupWalletNameModuleCreationResult = (
    view: BackupWalletNameViewInput,
    input: BackupWalletNameModuleInput
)

protocol BackupWalletNameRouterInput: AnyDismissable, SheetAlertPresentable, ErrorPresentable {
    func showWarningsScreen(
        walletName: String,
        from view: ControllerBackedProtocol?
    )
    func complete(view: ControllerBackedProtocol?)
}

protocol BackupWalletNameModuleInput: AnyObject {}

protocol BackupWalletNameModuleOutput: AnyObject {}
