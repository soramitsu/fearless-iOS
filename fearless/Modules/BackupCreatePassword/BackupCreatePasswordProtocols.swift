typealias BackupCreatePasswordModuleCreationResult = (
    view: BackupCreatePasswordViewInput,
    input: BackupCreatePasswordModuleInput
)

protocol BackupCreatePasswordRouterInput: AnyDismissable, SheetAlertPresentable, ErrorPresentable {
    func showPinSetup()
}

protocol BackupCreatePasswordModuleInput: AnyObject {}

protocol BackupCreatePasswordModuleOutput: AnyObject {
    func backupDidComplete()
}
