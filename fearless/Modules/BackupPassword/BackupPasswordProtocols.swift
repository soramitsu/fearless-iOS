typealias BackupPasswordModuleCreationResult = (
    view: BackupPasswordViewInput,
    input: BackupPasswordModuleInput
)

protocol BackupPasswordRouterInput: AnyDismissable, SheetAlertPresentable {
    func showWalletImportedScreen(
        backupAccounts: [BackupAccount],
        from view: ControllerBackedProtocol?
    )
}

protocol BackupPasswordModuleInput: AnyObject {}

protocol BackupPasswordModuleOutput: AnyObject {}
