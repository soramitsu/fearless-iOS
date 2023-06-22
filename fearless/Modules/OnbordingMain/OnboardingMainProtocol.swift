import Foundation
import SSFCloudStorage

protocol OnboardingMainViewProtocol: ControllerBackedProtocol, CloudStorageUIDelegate, LoadableViewProtocol {}

protocol OnboardingMainPresenterProtocol: AnyObject {
    func setup()
    func activateSignup()
    func activateAccountRestore()
    func activateTerms()
    func activatePrivacy()
    func activateGoogleBackup()
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, SheetAlertPresentable, WarningPresentable, PresentDismissable, AppUpdatePresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(
        defaultSource: AccountImportSource,
        from view: OnboardingMainViewProtocol?
    )
    func showKeystoreImport(from view: OnboardingMainViewProtocol?)
    func showBackupSelectWallet(
        accounts: [OpenBackupAccount],
        from view: ControllerBackedProtocol?
    )
    func showCreateFlow(from view: ControllerBackedProtocol?)
}

protocol OnboardingMainInteractorInputProtocol: AnyObject {
    func setup()
    func activateGoogleBackup()
}

protocol OnboardingMainInteractorOutputProtocol: AnyObject {
    func didSuggestKeystoreImport()
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>)
}

protocol OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol?
    static func createViewForAdding() -> OnboardingMainViewProtocol?
    static func createViewForConnection(item: ConnectionItem) -> OnboardingMainViewProtocol?
    static func createViewForAccountSwitch() -> OnboardingMainViewProtocol?
}
