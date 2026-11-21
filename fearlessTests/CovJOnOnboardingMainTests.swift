import XCTest
import UIKit
import UIKit.UIGestureRecognizerSubclass
import RobinHood
import SoraFoundation
import SSFCloudStorage
import SSFUtils
@testable import fearless

final class CovJOnMainView: UIViewController, OnboardingMainViewProtocol {
    var preinstalled: [Bool] = []
    var loadingStarts = 0
    var loadingStops = 0
    func didReceive(preinstalledWalletEnabled: Bool) { preinstalled.append(preinstalledWalletEnabled) }
    func didStartLoading() { loadingStarts += 1 }
    func didStopLoading() { loadingStops += 1 }
}

final class CovJOnMainWireframe: OnboardingMainWireframeProtocol {
    var webs: [(URL, WebPresentableStyle)] = []
    var sheets: [SheetAlertPresentableViewModel] = []
    var messages: [(title: String, message: String?, actions: [SheetAlertPresentableAction])] = []
    var signups = 0
    var restores: [AccountImportSource] = []
    var keystoreImports = 0
    var backupAccounts: [[OpenBackupAccount]] = []
    var createFlows = 0
    var preinstalledFlows = 0

    func showWeb(url: URL, from _: ControllerBackedProtocol, style: WebPresentableStyle) { webs.append((url, style)) }
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }
    func present(message: String?, title: String, closeAction _: String?, from _: ControllerBackedProtocol?, actions: [SheetAlertPresentableAction]) {
        messages.append((title, message, actions))
    }
    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
    func showSignup(from _: OnboardingMainViewProtocol?) { signups += 1 }
    func showAccountRestore(defaultSource: AccountImportSource, from _: OnboardingMainViewProtocol?) { restores.append(defaultSource) }
    func showKeystoreImport(from _: OnboardingMainViewProtocol?) { keystoreImports += 1 }
    func showBackupSelectWallet(accounts: [OpenBackupAccount], from _: ControllerBackedProtocol?) { backupAccounts.append(accounts) }
    func showCreateFlow(from _: ControllerBackedProtocol?) { createFlows += 1 }
    func showPreinstalledFlow(from _: ControllerBackedProtocol?) { preinstalledFlows += 1 }
}

final class CovJOnMainInteractor: OnboardingMainInteractorInputProtocol {
    var setups = 0
    var googleActivations = 0
    func setup() { setups += 1 }
    func activateGoogleBackup() { googleActivations += 1 }
}

final class CovJOnMainPresenterTests: XCTestCase {
    private let legal = LegalData(
        termsUrl: URL(string: "https://example.invalid/terms")!,
        privacyPolicyUrl: URL(string: "https://example.invalid/privacy")!
    )
    private let languages = CovJFixture.locale.rLanguages

    private func make(withView: Bool = true) -> (OnboardingMainPresenter, CovJOnMainWireframe, CovJOnMainInteractor, CovJOnMainView) {
        let wireframe = CovJOnMainWireframe()
        let interactor = CovJOnMainInteractor()
        let observer = AppVersionObserver(
            operationManager: OperationManager(),
            currentAppVersion: nil,
            wireframe: wireframe,
            locale: CovJFixture.locale
        )
        let presenter = OnboardingMainPresenter(
            legalData: legal,
            locale: CovJFixture.locale,
            appVersionObserver: observer,
            wireframe: wireframe,
            interactor: interactor
        )
        let view = CovJOnMainView()
        if withView { presenter.view = view }
        return (presenter, wireframe, interactor, view)
    }

    func testSetupAndSimpleRoutes() {
        let (presenter, wireframe, interactor, view) = make()
        presenter.setup()
        presenter.activateSignup()
        presenter.didTapGetPreinstalled()
        presenter.didSuggestKeystoreImport()
        presenter.activateTerms()
        presenter.activatePrivacy()
        XCTAssertEqual(interactor.setups, 1)
        XCTAssertEqual(wireframe.signups, 1)
        XCTAssertEqual(wireframe.preinstalledFlows, 1)
        XCTAssertEqual(wireframe.keystoreImports, 1)
        XCTAssertEqual(wireframe.webs.map(\.0), [legal.termsUrl, legal.privacyPolicyUrl])
        XCTAssertEqual(wireframe.webs.map(\.1), [.modal, .modal])
        XCTAssertTrue(presenter.view === view, "The presenter only holds its view weakly")
    }

    func testLegalPagesNeedAView() {
        let (presenter, wireframe, _, _) = make(withView: false)
        presenter.activateTerms()
        presenter.activatePrivacy()
        XCTAssertTrue(wireframe.webs.isEmpty)
    }

    func testRestoreChoiceOffersEverySourceAndGoogle() throws {
        let (presenter, wireframe, interactor, view) = make()
        presenter.activateAccountRestore()
        let sheet = try XCTUnwrap(wireframe.sheets.first)
        XCTAssertEqual(sheet.title, R.string.localizable.googleBackupChoiceTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.actions.map(\.title), [
            R.string.localizable.googleBackupChoiceMnemonic(preferredLanguages: languages),
            R.string.localizable.googleBackupChoiceRaw(preferredLanguages: languages),
            R.string.localizable.googleBackupChoiceJson(preferredLanguages: languages),
            R.string.localizable.googleBackupChoiceGoogle(preferredLanguages: languages),
            R.string.localizable.commonCancel(preferredLanguages: languages)
        ])
        XCTAssertNotNil(sheet.actions[3].button.imageWithTitleView?.iconImage)
        XCTAssertNil(sheet.actions[4].handler)
        for index in 0 ..< 4 { sheet.actions[index].handler?() }
        XCTAssertEqual(wireframe.restores, [.mnemonic, .seed, .keystore])
        XCTAssertEqual(view.loadingStarts, 1)
        XCTAssertEqual(interactor.googleActivations, 1)
    }

    func testBackupAccountsOpenSelectionAndFailureOffersRetry() throws {
        let (presenter, wireframe, interactor, view) = make()
        presenter.didReceiveBackupAccounts(result: .success([OpenBackupAccount(address: "5Backup")]))
        XCTAssertEqual(wireframe.backupAccounts.map { $0.map(\.address) }, [["5Backup"]])
        XCTAssertEqual(view.loadingStops, 1)

        presenter.didReceiveBackupAccounts(result: .failure(CovJError()))
        XCTAssertEqual(view.loadingStops, 2)
        let alert = try XCTUnwrap(wireframe.messages.first)
        XCTAssertEqual(alert.title, R.string.localizable.noAccessToGoogle(preferredLanguages: languages))
        XCTAssertNil(alert.message)
        XCTAssertEqual(alert.actions.map(\.title), [R.string.localizable.tryAgain(preferredLanguages: languages)])
        alert.actions.first?.handler?()
        XCTAssertEqual(interactor.googleActivations, 1)
        XCTAssertEqual(view.loadingStarts, 0, "Retry goes straight to the interactor")
    }

    func testFeatureToggleOnlyForwardsSuccessfulConfigs() {
        let (presenter, _, _, view) = make()
        let config = FeatureToggleConfig(pendulumCaseEnabled: true, nftEnabled: nil)
        presenter.didReceiveFeatureToggleConfig(result: .success(config))
        presenter.didReceiveFeatureToggleConfig(result: .failure(CovJError()))
        presenter.didReceiveFeatureToggleConfig(result: nil)
        XCTAssertEqual(view.preinstalled, [PreinstalledWalletImportPolicy.isAvailable(remote: config)])
    }
}

final class CovJOnKeystoreImportStub: KeystoreImportServiceProtocol {
    var definition: KeystoreDefinition?
    var observers: [KeystoreImportObserver] = []
    func add(observer: KeystoreImportObserver) { observers.append(observer) }
    func remove(observer _: KeystoreImportObserver) {}
    func clear() { definition = nil }
    func handle(url _: URL) -> Bool { false }
}

final class CovJOnCloudStub: CloudStorageServiceProtocol {
    private let lock = NSLock()
    private var disconnectCount = 0
    var accounts: Result<[OpenBackupAccount], Error> = .success([])
    var disconnects: Int { lock.lock(); defer { lock.unlock() }; return disconnectCount }
    var isUserAuthorized: Bool { false }
    func signInIfNeeded() async throws -> CloudStorageAccountState { .notAuthorized }
    func getBackupAccounts() async throws -> [OpenBackupAccount] { try accounts.get() }
    func saveBackup(account _: OpenBackupAccount, password _: String) async throws {}
    func saveBackupAndImport(account: OpenBackupAccount, password _: String) async throws -> OpenBackupAccount { account }
    func importBackup(account: OpenBackupAccount, password _: String) async throws -> OpenBackupAccount { account }
    func deleteBackup(account _: OpenBackupAccount) async throws {}
    func disconnect() { lock.lock(); disconnectCount += 1; lock.unlock() }
}

final class CovJOnToggleStub: FeatureToggleProviderProtocol {
    var result: Result<FeatureToggleConfig, Error> = .success(FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: true))
    func fetchConfigOperation() -> BaseOperation<FeatureToggleConfig> {
        let result = self.result
        return ClosureOperation { try result.get() }
    }
}

final class CovJOnMainOutput: OnboardingMainInteractorOutputProtocol {
    var suggestions = 0
    var backups: [Result<[OpenBackupAccount], Error>] = []
    var toggles: [Result<FeatureToggleConfig, Error>?] = []
    func didSuggestKeystoreImport() { suggestions += 1 }
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>) { backups.append(result) }
    func didReceiveFeatureToggleConfig(result: Result<FeatureToggleConfig, Error>?) { toggles.append(result) }
}

final class CovJOnMainInteractorTests: XCTestCase {
    private let definition = KeystoreDefinition(
        address: "5Keystore",
        encoded: "encoded",
        encoding: KeystoreEncoding(content: ["pkcs8", "sr25519"], type: ["scrypt", "xsalsa20-poly1305"], version: "3"),
        meta: nil
    )

    private func make(
        keystore: CovJOnKeystoreImportStub = CovJOnKeystoreImportStub(),
        cloud: CovJOnCloudStub = CovJOnCloudStub(),
        toggle: CovJOnToggleStub = CovJOnToggleStub()
    ) -> (OnboardingMainInteractor, CovJOnMainOutput) {
        let interactor = OnboardingMainInteractor(
            keystoreImportService: keystore,
            cloudStorage: cloud,
            featureToggleService: toggle,
            operationQueue: OperationQueue()
        )
        let output = CovJOnMainOutput()
        interactor.presenter = output
        return (interactor, output)
    }

    func testSetupObservesKeystoreAndDeliversFeatureToggleOnMain() throws {
        let keystore = CovJOnKeystoreImportStub()
        let (interactor, output) = make(keystore: keystore)
        interactor.setup()
        XCTAssertEqual(keystore.observers.count, 1)
        XCTAssertEqual(output.suggestions, 0)
        XCTAssertTrue(CovJWait.until { output.toggles.count == 1 })
        let config = try XCTUnwrap(output.toggles.first??.get())
        XCTAssertEqual(config.nftEnabled, true)

        interactor.didUpdateDefinition(from: nil)
        XCTAssertEqual(output.suggestions, 0)
        keystore.definition = definition
        interactor.didUpdateDefinition(from: nil)
        XCTAssertEqual(output.suggestions, 1)
    }

    func testSetupWithPendingKeystoreSuggestsImportAndForwardsToggleFailure() {
        let keystore = CovJOnKeystoreImportStub()
        keystore.definition = definition
        let toggle = CovJOnToggleStub()
        toggle.result = .failure(CovJError("toggle"))
        let (interactor, output) = make(keystore: keystore, toggle: toggle)
        interactor.setup()
        XCTAssertEqual(output.suggestions, 1)
        XCTAssertTrue(CovJWait.until { output.toggles.count == 1 })
        guard case .failure? = output.toggles.first ?? nil else {
            return XCTFail("Expected the failed fetch to be forwarded")
        }
    }

    func testGoogleBackupDeliversAccountsOrFailureAndDisconnects() {
        let cloud = CovJOnCloudStub()
        cloud.accounts = .success([OpenBackupAccount(address: "5Cloud")])
        let (interactor, output) = make(cloud: cloud)
        interactor.activateGoogleBackup()
        XCTAssertTrue(CovJWait.until { output.backups.count == 1 })
        XCTAssertEqual((try? output.backups.first?.get())?.map(\.address), ["5Cloud"])
        XCTAssertEqual(cloud.disconnects, 1)

        cloud.accounts = .failure(CovJError("drive"))
        interactor.activateGoogleBackup()
        XCTAssertTrue(CovJWait.until { output.backups.count == 2 })
        guard case let .failure(error)? = output.backups.last else {
            return XCTFail("Expected a failure")
        }
        XCTAssertEqual(error as? CovJError, CovJError("drive"))
        XCTAssertEqual(cloud.disconnects, 3)
    }

    func testReleasingTheInteractorDisconnectsCloudStorage() {
        let cloud = CovJOnCloudStub()
        autoreleasepool {
            _ = make(cloud: cloud)
        }
        XCTAssertEqual(cloud.disconnects, 1)
    }
}

final class CovJOnTermsTap: UITapGestureRecognizer {
    var point = CGPoint.zero
    var forcedState: UIGestureRecognizer.State = .possible
    override var state: UIGestureRecognizer.State {
        get { forcedState }
        set { forcedState = newValue }
    }
    override func location(in _: UIView?) -> CGPoint { point }
}

final class CovJOnMainPresenterSpy: OnboardingMainPresenterProtocol {
    var actions: [String] = []
    func setup() { actions.append("setup") }
    func activateSignup() { actions.append("signup") }
    func activateAccountRestore() { actions.append("restore") }
    func activateTerms() { actions.append("terms") }
    func activatePrivacy() { actions.append("privacy") }
    func didTapGetPreinstalled() { actions.append("preinstalled") }
}

final class CovJOnMainControllerTests: XCTestCase {
    func testLegacyLayoutRoutesNibActionsAndTermsTaps() throws {
        let controller = OnboardingMainViewController(nib: R.nib.onbordingMain)
        let presenter = CovJOnMainPresenterSpy()
        controller.presenter = presenter
        controller.welcomeAppearanceEnabled = false
        controller.localizationManager = LocalizationManager.shared
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        controller.perform(NSSelectorFromString("actionSignupWithSender:"), with: UIButton())
        controller.perform(NSSelectorFromString("actionRestoreAccessWithSender:"), with: UIButton())
        controller.actionPreinstalled()
        let tap = CovJOnTermsTap()
        controller.perform(NSSelectorFromString("actionTermsWithGestureRecognizer:"), with: tap)
        tap.forcedState = .ended
        tap.point = CGPoint(x: -1000, y: 0)
        controller.perform(NSSelectorFromString("actionTermsWithGestureRecognizer:"), with: tap)
        tap.point = CGPoint(x: 10000, y: 0)
        controller.perform(NSSelectorFromString("actionTermsWithGestureRecognizer:"), with: tap)
        XCTAssertEqual(presenter.actions, ["setup", "signup", "restore", "preinstalled", "terms", "privacy"])

        XCTAssertNil(controller.welcomeView)
        XCTAssertTrue(controller.flightTiers.isEmpty)
        XCTAssertTrue(controller.preInstalledButton.isHidden)
        controller.didReceive(preinstalledWalletEnabled: true)
        XCTAssertFalse(controller.preInstalledButton.isHidden)
        controller.applyLocalization()
        XCTAssertEqual(
            controller.preInstalledButton.imageWithTitleView?.title,
            R.string.localizable.onboardingPreinstalledWalletButtonText(preferredLanguages: controller.selectedLocale.rLanguages)
        )
        XCTAssertEqual(controller.navigationItem.rightBarButtonItem?.title, RecoveryText.string("previous_data"))
    }

    func testWelcomeLayoutExposesFlightTiersAndHidesPreinstalledChoice() throws {
        let controller = OnboardingMainViewController(nib: R.nib.onbordingMain)
        let presenter = CovJOnMainPresenterSpy()
        controller.presenter = presenter
        controller.welcomeAppearanceEnabled = true
        controller.localizationManager = LocalizationManager.shared
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let welcome = try XCTUnwrap(controller.welcomeView)
        XCTAssertFalse(controller.flightTiers.isEmpty)
        controller.didReceive(preinstalledWalletEnabled: false)
        XCTAssertTrue(welcome.preinstalledButton.isHidden)
        controller.didReceive(preinstalledWalletEnabled: true)
        XCTAssertFalse(welcome.preinstalledButton.isHidden)
        welcome.termsButton.sendActions(for: .touchUpInside)
        welcome.privacyButton.sendActions(for: .touchUpInside)
        welcome.preinstalledButton.sendActions(for: .touchUpInside)
        controller.applyLocalization()
        XCTAssertEqual(presenter.actions, ["setup", "terms", "privacy", "preinstalled"])
    }
}

final class CovJOnMainRoutingTests: XCTestCase {
    private func host() throws -> (CovJOnMainView, UINavigationController, UIWindow) {
        let view = CovJOnMainView()
        let navigation = UINavigationController(rootViewController: view)
        let window = try CovJViewFixture.host(navigation)
        return (view, navigation, window)
    }

    func testSignupPushesUsernameSetupAndCreateFlowPresentsWalletName() throws {
        let (view, navigation, window) = try host()
        defer {
            navigation.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        let wireframe = OnboardingMainWireframe()
        wireframe.showSignup(from: view)
        XCTAssertTrue(navigation.viewControllers.last is UsernameSetupViewController)
        CovJWait.until(timeout: 3) { navigation.transitionCoordinator == nil }
        CovJWait.drain(0.3)
        wireframe.showCreateFlow(from: view)
        XCTAssertTrue(CovJWait.until { navigation.presentedViewController != nil })
        let presented = try XCTUnwrap(navigation.presentedViewController as? UINavigationController)
        XCTAssertTrue(presented.viewControllers.first is WalletNameViewController)
    }

    func testImportRoutesNeedTheKeystoreImportService() throws {
        let (view, navigation, window) = try host()
        defer { window.isHidden = true }
        let installed: KeystoreImportServiceProtocol? = URLHandlingService.shared.findService()
        XCTAssertNil(installed, "Unit-test launches install no URL handlers")
        let wireframe = OnboardingMainWireframe()
        wireframe.showAccountRestore(defaultSource: .seed, from: view)
        wireframe.showKeystoreImport(from: view)
        wireframe.showKeystoreImport(from: nil)
        wireframe.showPreinstalledFlow(from: view)
        XCTAssertEqual(navigation.viewControllers.count, 1)
        XCTAssertNil(OnboardingMainViewFactory.createViewForOnboarding())
        XCTAssertNil(OnboardingMainViewFactory.createViewForAdding())
        XCTAssertNil(OnboardingMainViewFactory.createViewForAccountSwitch())
    }
}
