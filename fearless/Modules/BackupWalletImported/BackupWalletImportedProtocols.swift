import SSFCloudStorage

typealias BackupWalletImportedModuleCreationResult = (
    view: BackupWalletImportedViewInput,
    input: BackupWalletImportedModuleInput
)

protocol BackupWalletImportedRouterInput: PresentDismissable {
    func showBackupSelectWallet(
        for accounts: [OpenBackupAccount],
        from view: ControllerBackedProtocol?
    )
    func showSetupPin(from view: ControllerBackedProtocol?)
    func backButtonDidTapped(from view: ControllerBackedProtocol?)
}

protocol BackupWalletImportedModuleInput: AnyObject {}

protocol BackupWalletImportedModuleOutput: AnyObject {}
