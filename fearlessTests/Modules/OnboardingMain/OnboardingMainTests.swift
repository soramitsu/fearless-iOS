import XCTest
import UIKit
import FearlessFoundation
@testable import fearless
import SSFCloudStorage

final class OnboardingMainTests: XCTestCase {
    private let legalData = LegalData(
        termsUrl: URL(string: "https://example.com/terms")!,
        privacyPolicyUrl: URL(string: "https://example.com/privacy")!
    )

    func testSetup_whenCalled_thenStartsInteractorSetup() {
        let fixture = createFixture()

        fixture.presenter.setup()

        XCTAssertEqual(fixture.interactor.setupCallCount, 1)
    }

    func testPrimaryActions_whenActivated_thenRouteThroughWireframe() {
        let fixture = createFixture()

        fixture.presenter.activateSignup()
        fixture.presenter.activateTerms()
        fixture.presenter.activatePrivacy()
        fixture.presenter.didTapGetPreinstalled()

        XCTAssertEqual(fixture.wireframe.showSignupCallCount, 1)
        XCTAssertEqual(fixture.wireframe.shownWebUrls, [legalData.termsUrl, legalData.privacyPolicyUrl])
        XCTAssertEqual(fixture.wireframe.shownWebStyles, [.modal, .modal])
        XCTAssertEqual(fixture.wireframe.showPreinstalledFlowCallCount, 1)
    }

    func testActivateAccountRestore_whenSourceActionsSelected_thenRoutesWithDefaultSources() {
        let fixture = createFixture()

        fixture.presenter.activateAccountRestore()

        XCTAssertEqual(fixture.wireframe.presentedSheet?.actions.count, 5)
        fixture.wireframe.presentedSheet?.actions[0].handler?()
        fixture.wireframe.presentedSheet?.actions[1].handler?()
        fixture.wireframe.presentedSheet?.actions[2].handler?()

        XCTAssertEqual(
            fixture.wireframe.accountRestoreSources,
            [.mnemonic, .seed, .keystore]
        )
    }

    func testActivateAccountRestore_whenGoogleActionSelected_thenStartsBackupLoading() {
        let fixture = createFixture()

        fixture.presenter.activateAccountRestore()
        fixture.wireframe.presentedSheet?.actions[3].handler?()

        XCTAssertEqual(fixture.view.startLoadingCallCount, 1)
        XCTAssertEqual(fixture.interactor.activateGoogleBackupCallCount, 1)
    }

    func testDidSuggestKeystoreImport_whenReceived_thenRoutesToKeystoreImport() {
        let fixture = createFixture()

        fixture.presenter.didSuggestKeystoreImport()

        XCTAssertEqual(fixture.wireframe.showKeystoreImportCallCount, 1)
    }

    func testDidReceiveBackupAccounts_whenSuccess_thenStopsLoadingAndShowsBackupWallets() {
        let fixture = createFixture()

        fixture.presenter.didReceiveBackupAccounts(result: .success([]))

        XCTAssertEqual(fixture.view.stopLoadingCallCount, 1)
        XCTAssertEqual(fixture.wireframe.backupSelectWalletCallCount, 1)
        XCTAssertEqual(fixture.wireframe.backupSelectWalletAccountCounts, [0])
    }

    func testDidReceiveBackupAccounts_whenFailureRetrySelected_thenRetriesGoogleBackup() {
        let fixture = createFixture()

        fixture.presenter.didReceiveBackupAccounts(result: .failure(OnboardingMainTestError.expected))
        fixture.wireframe.presentedMessageActions.first?.handler?()

        XCTAssertEqual(fixture.view.stopLoadingCallCount, 1)
        XCTAssertEqual(fixture.wireframe.presentedMessageTitles.count, 1)
        XCTAssertEqual(fixture.interactor.activateGoogleBackupCallCount, 1)
    }

    func testDidReceiveFeatureToggleConfig_whenPreinstalledEnabled_thenUpdatesView() {
        let fixture = createFixture()
        let config = FeatureToggleConfig(pendulumCaseEnabled: true, nftEnabled: true)

        fixture.presenter.didReceiveFeatureToggleConfig(result: .success(config))

        XCTAssertEqual(fixture.view.preinstalledWalletStates, [true])
    }

    func testCreateView_whenKeystoreImportServiceMissing_thenReturnsNilAndLogs() {
        let logger = LoggerSpy()
        let dependencies = OnboardingMainViewFactory.Dependencies(
            keystoreImportServiceProvider: { nil },
            logger: logger
        )

        XCTAssertNil(OnboardingMainViewFactory.createViewForOnboarding(dependencies: dependencies))
        XCTAssertNil(OnboardingMainViewFactory.createViewForAdding(dependencies: dependencies))
        XCTAssertNil(OnboardingMainViewFactory.createViewForAccountSwitch(dependencies: dependencies))
        XCTAssertEqual(
            logger.errorMessages,
            [
                "Can't find required keystore import service",
                "Can't find required keystore import service",
                "Can't find required keystore import service"
            ]
        )
    }

    private func createFixture() -> (
        presenter: OnboardingMainPresenter,
        view: OnboardingMainViewSpy,
        wireframe: OnboardingMainWireframeSpy,
        interactor: OnboardingMainInteractorSpy
    ) {
        let view = OnboardingMainViewSpy()
        let wireframe = OnboardingMainWireframeSpy()
        let interactor = OnboardingMainInteractorSpy()
        let locale = Locale(identifier: "en")
        let appVersionObserver = AppVersionObserver(
            operationManager: OperationManagerFacade.sharedManager,
            currentAppVersion: nil,
            wireframe: wireframe,
            locale: locale
        )
        let presenter = OnboardingMainPresenter(
            legalData: legalData,
            locale: locale,
            appVersionObserver: appVersionObserver,
            wireframe: wireframe,
            interactor: interactor
        )
        presenter.view = view

        return (presenter, view, wireframe, interactor)
    }
}

private final class OnboardingMainInteractorSpy: OnboardingMainInteractorInputProtocol {
    private(set) var setupCallCount = 0
    private(set) var activateGoogleBackupCallCount = 0

    func setup() {
        setupCallCount += 1
    }

    func activateGoogleBackup() {
        activateGoogleBackupCallCount += 1
    }
}

private final class OnboardingMainViewSpy: OnboardingMainViewProtocol {
    let controller = UIViewController()
    var isSetup: Bool { controller.isViewLoaded }
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true

    private(set) var startLoadingCallCount = 0
    private(set) var stopLoadingCallCount = 0
    private(set) var preinstalledWalletStates: [Bool] = []

    func didStartLoading() {
        startLoadingCallCount += 1
    }

    func didStopLoading() {
        stopLoadingCallCount += 1
    }

    func didReceive(preinstalledWalletEnabled: Bool) {
        preinstalledWalletStates.append(preinstalledWalletEnabled)
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }
}

private final class OnboardingMainWireframeSpy: OnboardingMainWireframeProtocol {
    private(set) var showSignupCallCount = 0
    private(set) var showKeystoreImportCallCount = 0
    private(set) var showPreinstalledFlowCallCount = 0
    private(set) var backupSelectWalletCallCount = 0
    private(set) var backupSelectWalletAccountCounts: [Int] = []
    private(set) var accountRestoreSources: [AccountImportSource] = []
    private(set) var shownWebUrls: [URL] = []
    private(set) var shownWebStyles: [WebPresentableStyle] = []
    private(set) var presentedSheet: SheetAlertPresentableViewModel?
    private(set) var presentedMessageTitles: [String] = []
    private(set) var presentedMessageActions: [SheetAlertPresentableAction] = []
    private(set) var dismissCallCount = 0
    private(set) var appstoreUpdateCallCount = 0
    private(set) var warningAlertConfigs: [WarningAlertConfig] = []

    func showSignup(from _: OnboardingMainViewProtocol?) {
        showSignupCallCount += 1
    }

    func showAccountRestore(
        defaultSource: AccountImportSource,
        from _: OnboardingMainViewProtocol?
    ) {
        accountRestoreSources.append(defaultSource)
    }

    func showKeystoreImport(from _: OnboardingMainViewProtocol?) {
        showKeystoreImportCallCount += 1
    }

    func showBackupSelectWallet(
        accounts: [OpenBackupAccount],
        from _: ControllerBackedProtocol?
    ) {
        backupSelectWalletCallCount += 1
        backupSelectWalletAccountCounts.append(accounts.count)
    }

    func showCreateFlow(from _: ControllerBackedProtocol?) {}

    func showPreinstalledFlow(from _: ControllerBackedProtocol?) {
        showPreinstalledFlowCallCount += 1
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style: WebPresentableStyle) {
        shownWebUrls.append(url)
        shownWebStyles.append(style)
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {
        presentedSheet = viewModel
    }

    func present(
        message _: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {
        presentedMessageTitles.append(title)
        presentedMessageActions = actions
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }

    func dismiss(view _: ControllerBackedProtocol?) {
        dismissCallCount += 1
    }

    func presentWarningAlert(
        from _: ControllerBackedProtocol?,
        config: WarningAlertConfig,
        buttonHandler _: @escaping WarningAlertButtonHandler
    ) {
        warningAlertConfigs.append(config)
    }

    func showAppstoreUpdatePage() {
        appstoreUpdateCallCount += 1
    }
}

private enum OnboardingMainTestError: Error {
    case expected
}

private final class LoggerSpy: LoggerProtocol {
    private(set) var errorMessages: [String] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}

    func error(message: String, file _: String, function _: String, line _: Int) {
        errorMessages.append(message)
    }

    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
