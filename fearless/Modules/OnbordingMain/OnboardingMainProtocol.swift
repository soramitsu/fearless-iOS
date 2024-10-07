import Foundation
import SSFCloudStorage

protocol OnboardingMainViewProtocol: ControllerBackedProtocol, LoadableViewProtocol, SheetAlertPresentable {
    func didReceive(preinstalledWalletEnabled: Bool)
}

protocol OnboardingMainPresenterProtocol: AnyObject {
    func setup()
    func activateSignup()
    func activateAccountRestore()
    func activateTerms()
    func activatePrivacy()
    func didTapGetPreinstalled()
    func didSelect(ecosystem: AccountCreateEcosystem)
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, SheetAlertPresentable, WarningPresentable, PresentDismissable, AppUpdatePresentable {
    func showSignup(
        from view: OnboardingMainViewProtocol?,
        ecosystem: AccountCreateEcosystem
    )
    func showAccountRestore(
        defaultSource: AccountImportSource,
        flow: AccountImportFlow,
        from view: OnboardingMainViewProtocol?
    )
    func showKeystoreImport(from view: OnboardingMainViewProtocol?)
    func showBackupSelectWallet(
        accounts: [OpenBackupAccount],
        from view: ControllerBackedProtocol?
    )
    func showCreateFlow(from view: ControllerBackedProtocol?)
    func showPreinstalledFlow(from view: ControllerBackedProtocol?)
}

protocol OnboardingMainInteractorInputProtocol: AnyObject {
    func setup()
    func activateGoogleBackup()
}

protocol OnboardingMainInteractorOutputProtocol: AnyObject {
    func didSuggestKeystoreImport()
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>)
    func didReceiveFeatureToggleConfig(result: Result<FeatureToggleConfig, Error>?)
}

protocol OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol?
    static func createViewForAdding() -> OnboardingMainViewProtocol?
    static func createViewForAccountSwitch() -> OnboardingMainViewProtocol?
}
