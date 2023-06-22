import Foundation
import SSFCloudStorage

typealias BackupSelectWalletModuleCreationResult = (
    view: BackupSelectWalletViewInput,
    input: BackupSelectWalletModuleInput
)

protocol BackupSelectWalletRouterInput: PresentDismissable {
    func presentBackupPasswordScreen(
        for backupAccounts: [BackupAccount],
        from view: ControllerBackedProtocol?
    )
}

protocol BackupSelectWalletModuleInput: AnyObject {}

protocol BackupSelectWalletModuleOutput: AnyObject {}
