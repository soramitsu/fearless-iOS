typealias BackupWalletModuleCreationResult = (
    view: BackupWalletViewInput,
    input: BackupWalletModuleInput
)

protocol BackupWalletRouterInput: AnyDismissable, SheetAlertPresentable, ErrorPresentable, AuthorizationPresentable, ModalAlertPresenting {
    func showMnemonicExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    )
    func showKeystoreExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    )
    func showSeedExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    )
    func showCreatePassword(
        wallet: MetaAccountModel,
        request: BackupCreatePasswordFlow.RequestType,
        from view: ControllerBackedProtocol?,
        moduleOutput: BackupCreatePasswordModuleOutput?
    )
    func showWalletDetails(
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol BackupWalletModuleInput: AnyObject {}

protocol BackupWalletModuleOutput: AnyObject {}
