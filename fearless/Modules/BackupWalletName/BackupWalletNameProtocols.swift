typealias BackupWalletNameModuleCreationResult = (
    view: BackupWalletNameViewInput,
    input: BackupWalletNameModuleInput
)

protocol BackupWalletNameRouterInput: AnyDismissable {
    func showWarningsScreen(
        walletName: String,
        from view: ControllerBackedProtocol?
    )
}

protocol BackupWalletNameModuleInput: AnyObject {}

protocol BackupWalletNameModuleOutput: AnyObject {}
