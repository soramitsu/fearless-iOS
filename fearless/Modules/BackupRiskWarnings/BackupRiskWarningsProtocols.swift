typealias BackupRiskWarningsModuleCreationResult = (
    view: BackupRiskWarningsViewInput,
    input: BackupRiskWarningsModuleInput
)

protocol BackupRiskWarningsRouterInput: AnyDismissable {}

protocol BackupRiskWarningsModuleInput: AnyObject {}

protocol BackupRiskWarningsModuleOutput: AnyObject {}
