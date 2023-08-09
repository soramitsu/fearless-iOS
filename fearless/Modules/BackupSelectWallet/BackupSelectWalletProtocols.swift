import Foundation
import SSFCloudStorage

typealias BackupSelectWalletModuleCreationResult = (
    view: BackupSelectWalletViewInput,
    input: BackupSelectWalletModuleInput
)

protocol BackupSelectWalletRouterInput: PresentDismissable, SheetAlertPresentable, ErrorPresentable {
    func presentBackupPasswordScreen(
        for backupAccounts: [BackupAccount],
        from view: ControllerBackedProtocol?
    )
    func showWalletNameScreen(from view: ControllerBackedProtocol?)
}

protocol BackupSelectWalletModuleInput: AnyObject {}

protocol BackupSelectWalletModuleOutput: AnyObject {}
