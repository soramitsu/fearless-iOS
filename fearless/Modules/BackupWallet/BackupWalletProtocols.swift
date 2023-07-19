typealias BackupWalletModuleCreationResult = (
    view: BackupWalletViewInput,
    input: BackupWalletModuleInput
)

protocol BackupWalletRouterInput: AnyDismissable, SheetAlertPresentable, ErrorPresentable, AuthorizationPresentable {
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
        request: MetaAccountImportMnemonicRequest,
        from view: ControllerBackedProtocol?,
        moduleOutput: BackupCreatePasswordModuleOutput?
    )
}

protocol BackupWalletModuleInput: AnyObject {}

protocol BackupWalletModuleOutput: AnyObject {}
