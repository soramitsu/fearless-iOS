import SSFCloudStorage

typealias BackupWalletImportedModuleCreationResult = (
    view: BackupWalletImportedViewInput,
    input: BackupWalletImportedModuleInput
)

protocol BackupWalletImportedRouterInput: AnyDismissable {
    func showBackupSelectWallet(
        for accounts: [OpenBackupAccount],
        from view: ControllerBackedProtocol?
    )
    func showSetupPin(from view: ControllerBackedProtocol?)
}

protocol BackupWalletImportedModuleInput: AnyObject {}

protocol BackupWalletImportedModuleOutput: AnyObject {}
