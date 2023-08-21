typealias BackupCreatePasswordModuleCreationResult = (
    view: BackupCreatePasswordViewInput,
    input: BackupCreatePasswordModuleInput
)

protocol BackupCreatePasswordRouterInput: SheetAlertPresentable, ErrorPresentable {
    func showPinSetup()
    func pop(from view: ControllerBackedProtocol?)
    func dismiss(from view: ControllerBackedProtocol?)
}

protocol BackupCreatePasswordModuleInput: AnyObject {}

protocol BackupCreatePasswordModuleOutput: AnyObject {
    func backupDidComplete()
}
