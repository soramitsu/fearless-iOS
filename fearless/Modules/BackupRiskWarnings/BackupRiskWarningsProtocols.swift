typealias BackupRiskWarningsModuleCreationResult = (
    view: BackupRiskWarningsViewInput,
    input: BackupRiskWarningsModuleInput
)

protocol BackupRiskWarningsRouterInput: AnyDismissable {
    func showCreateAccount(
        usernameModel: UsernameSetupModel,
        from view: ControllerBackedProtocol?
    )
}

protocol BackupRiskWarningsModuleInput: AnyObject {}

protocol BackupRiskWarningsModuleOutput: AnyObject {}
