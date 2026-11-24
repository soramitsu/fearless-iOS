import XCTest
import UIKit
import SoraFoundation
import SoraKeystore
@testable import fearless

final class CovJOnRootWireframe: RootWireframeProtocol {
    var events: [String] = []
    var onboardingVersions: [String] = []
    func showSplash(splashView _: ControllerBackedProtocol?, on _: UIWindow) { events.append("splash") }
    func showLocalAuthentication(on _: UIWindow) { events.append("pin") }
    func showMain(on _: UIWindow) { events.append("main") }
    func showPincodeSetup(on _: UIWindow) { events.append("pinSetup") }
    func showBroken(on _: UIWindow) { events.append("broken") }
    func showOnboarding(on _: UIWindow, with config: OnboardingConfigWrapper) {
        events.append("onboarding")
        onboardingVersions.append(config.minVersion)
    }
}

final class CovJOnRootInteractor: RootInteractorInputProtocol {
    var setups: [Bool] = []
    var recoveries: [StartupRecoveryViewModel.Action] = []
    var config: OnboardingConfigWrapper?
    func recover(_ action: StartupRecoveryViewModel.Action) { recoveries.append(action) }
    func setup(runMigrations: Bool) { setups.append(runMigrations) }
    func fetchOnboardingConfig() async throws -> OnboardingConfigWrapper? { config }
}

final class CovJOnReadinessSpy: RootStartupReadinessReporting {
    var slow: [(RootSetupPhase, TimeInterval)] = []
    var ready = 0
    var failures: [RootSetupFailure] = []
    func reportSlow(phase: RootSetupPhase, elapsedTime: TimeInterval) { slow.append((phase, elapsedTime)) }
    func reportReady() { ready += 1 }
    func reportFailure(_ failure: RootSetupFailure) { failures.append(failure) }
}

final class CovJOnRootView: UIViewController, RootViewProtocol {
    var states: [RootViewState] = []
    func didReceive(state: RootViewState) { states.append(state) }
}

final class CovJOnRootPresenterTests: XCTestCase {
    private struct CovJOnRootParts {
        let presenter: RootPresenter
        let wireframe: CovJOnRootWireframe
        let interactor: CovJOnRootInteractor
        let reporter: CovJOnReadinessSpy
    }

    private func make(start: Result<StartView, Error>, view: ControllerBackedProtocol? = nil) -> CovJOnRootParts {
        let wireframe = CovJOnRootWireframe()
        let interactor = CovJOnRootInteractor()
        let reporter = CovJOnReadinessSpy()
        let presenter = RootPresenter(
            localizationManager: LocalizationManager.shared,
            startViewHelper: CovJOnStartViewStub(start),
            onboardingConfigTimeoutNanoseconds: 2_000_000_000,
            startupReadinessReporter: reporter
        )
        presenter.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        presenter.view = view
        return CovJOnRootParts(presenter: presenter, wireframe: wireframe, interactor: interactor, reporter: reporter)
    }

    func testReloadThatCannotOpenTheStoredWalletOffersWalletRecovery() throws {
        let view = CovJOnRootView()
        let parts = make(start: .failure(StartViewError.selectedWalletUnavailable), view: view)
        parts.presenter.reload()
        parts.presenter.reload()
        XCTAssertEqual(parts.interactor.setups, [false, false])
        XCTAssertEqual(view.states.count, 1, "Only the first reload resets the screen")

        parts.presenter.didUpdateSetup(.ready)
        XCTAssertEqual(parts.wireframe.events, ["broken"])
        let failure = try XCTUnwrap(parts.reporter.failures.first)
        XCTAssertEqual(failure.phase, .selectedWalletOpening)
        XCTAssertEqual(failure.incidentCode, .walletRecordRejected)
        XCTAssertEqual(failure.recoveryAction, .restoreWalletAccess)
        XCTAssertGreaterThanOrEqual(failure.elapsedTime, 0)
        XCTAssertEqual(parts.reporter.ready, 0)
    }

    func testUnexpectedStartErrorIsRetryable() throws {
        let parts = make(start: .failure(CovJError("store")))
        parts.presenter.reload()
        parts.presenter.didUpdateSetup(.ready)
        let failure = try XCTUnwrap(parts.reporter.failures.first)
        XCTAssertEqual(failure.incidentCode, .selectedWalletOpeningFailed)
        XCTAssertEqual(failure.recoveryAction, .retry)
        XCTAssertEqual(parts.wireframe.events, ["broken"])
    }

    func testReadyWithoutARunningSetupIsIgnored() {
        let parts = make(start: .success(.login))
        parts.presenter.didUpdateSetup(.ready)
        parts.presenter.didUpdateSetup(.failed(RootSetupFailure(
            phase: .languageMigration,
            incidentCode: .languageMigrationFailed,
            elapsedTime: 0,
            recoveryAction: .retry
        )))
        XCTAssertTrue(parts.wireframe.events.isEmpty)
        XCTAssertEqual(parts.reporter.ready, 0)
        XCTAssertTrue(parts.reporter.failures.isEmpty)
    }

    func testLaunchWithoutInteractorFallsBackToTheStartViewWithoutOnboarding() {
        let parts = make(start: .success(.login))
        parts.presenter.loadOnLaunch()
        XCTAssertEqual(parts.interactor.setups, [true])
        XCTAssertEqual(parts.wireframe.events, ["splash"])
        parts.presenter.interactor = nil
        parts.presenter.didUpdateSetup(.ready)
        XCTAssertTrue(CovJWait.until(timeout: 3) { parts.wireframe.events.contains("main") })
        XCTAssertEqual(parts.wireframe.events, ["splash", "main"])
        XCTAssertEqual(parts.reporter.ready, 1)
    }

    func testLaunchRoutesEveryStartView() throws {
        let config = try CovJOnOnboardingFixture.config(minVersion: "5.0.0")
        let expectations: [(StartView, String)] = [(.pin, "pin"), (.pinSetup, "pinSetup"), (.onboarding(config), "onboarding")]
        for (start, event) in expectations {
            let parts = make(start: .success(start))
            parts.presenter.loadOnLaunch()
            parts.presenter.didUpdateSetup(.ready)
            XCTAssertTrue(CovJWait.until(timeout: 3) { parts.wireframe.events.contains(event) }, event)
            XCTAssertEqual(parts.reporter.ready, 1, event)
        }
    }

    func testRecoveryActionsRetryRouteOrDelegate() {
        let parts = make(start: .success(.login))
        parts.presenter.recoverAfterFailure(.retry, phase: .substrateMigration)
        XCTAssertEqual(parts.wireframe.events, ["splash"])
        XCTAssertEqual(parts.interactor.setups, [true])
        parts.presenter.recoverAfterFailure(.restoreWalletAccess, phase: .selectedWalletOpening)
        XCTAssertEqual(parts.wireframe.events, ["splash", "main"])
        parts.presenter.recoverAfterFailure(.restoreWalletAccess, phase: .userStorageMigration)
        parts.presenter.recoverAfterFailure(.continueInEnglish, phase: .languageMigration)
        XCTAssertEqual(parts.interactor.recoveries, [.restoreWalletAccess, .continueInEnglish])
    }

    func testRecoveryScreenRetryButtonRestartsStartup() throws {
        let view = CovJOnRootView()
        let window = try CovJViewFixture.host(view)
        defer {
            view.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        let parts = make(start: .success(.login), view: view)
        parts.presenter.didFailSetup(RootSetupFailure(
            phase: .substrateMigration,
            incidentCode: .substrateMigrationFailed,
            elapsedTime: 1,
            recoveryAction: .retry
        ))
        XCTAssertEqual(parts.reporter.failures.count, 1)
        XCTAssertTrue(CovJWait.until(timeout: 3) { view.presentedViewController is StartupRecoveryViewController })
        let recovery = try XCTUnwrap(view.presentedViewController as? StartupRecoveryViewController)
        XCTAssertTrue(CovJWait.until(timeout: 3) { !recovery.isBeingPresented })
        CovJWait.drain(0.3)
        let layout = try XCTUnwrap(recovery.view as? StartupRecoveryViewLayout)
        let retry = try XCTUnwrap(layout.stack.arrangedSubviews.compactMap { $0 as? UIButton }.first)
        retry.sendActions(for: .touchUpInside)
        XCTAssertTrue(CovJWait.until(timeout: 5) { parts.interactor.setups == [true] })
        XCTAssertEqual(parts.wireframe.events, ["splash"])
    }
}

final class CovJOnReadinessReporterTests: XCTestCase {
    func testReadyMarkerIsEmittedOnceWhateverWasReportedBefore() {
        var markers = 0
        let reporter = RootStartupReadinessReporter(readyMarkerEmitter: { _ in markers += 1 })
        let actions: [RootSetupRecoveryAction] = [
            .retry,
            .restoreWalletAccess,
            .continueWithFreshNetworkData,
            .freeStorage(requiredByteCount: 1_048_576)
        ]
        for action in actions {
            reporter.reportFailure(RootSetupFailure(
                phase: .userStorageMigration,
                incidentCode: .insufficientStorage,
                elapsedTime: -1,
                recoveryAction: action
            ))
        }
        reporter.reportSlow(phase: .substratePreflight, elapsedTime: 12.5)
        XCTAssertEqual(markers, 0)
        reporter.reportReady()
        reporter.reportReady()
        XCTAssertEqual(markers, 1)
    }
}

final class CovJOnRootFactoryTests: XCTestCase {
    func testDefaultDependenciesUseTheAppServicesLazily() {
        let dependencies = RootPresenterFactory.Dependencies.default
        XCTAssertTrue(dependencies.settings === SettingsManager.shared)
        XCTAssertTrue(dependencies.keystore is Keychain)
        XCTAssertTrue(dependencies.protectedDataAvailabilityMonitor is RootUIApplicationProtectedDataAvailabilityMonitor)
        XCTAssertTrue(dependencies.localizationManager === LocalizationManager.shared)
    }

    func testFactoryWiresPresenterInteractorViewAndWireframeWithoutStarting() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let defaults = RootPresenterFactory.Dependencies.default
        let dependencies = RootPresenterFactory.Dependencies(
            settings: defaults.settings,
            selectedWalletSettingsProvider: defaults.selectedWalletSettingsProvider,
            chainRegistryProvider: defaults.chainRegistryProvider,
            storagePreflightProvider: defaults.storagePreflightProvider,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: EventCenter.shared,
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared,
            onboardingService: defaults.onboardingService,
            onboardingConfigResolver: OnboardingConfigVersionResolver(userDefaultsStorage: InMemorySettingsManager()),
            keystore: InMemoryKeychain(),
            protectedDataAvailabilityMonitor: defaults.protectedDataAvailabilityMonitor
        )
        for created in [
            RootPresenterFactory.createPresenter(with: window, dependencies: dependencies),
            RootPresenterFactory.createPresenter(with: window)
        ] {
            let presenter = try XCTUnwrap(created as? RootPresenter)
            XCTAssertTrue(presenter.window === window)
            XCTAssertTrue(presenter.wireframe is RootWireframe)
            XCTAssertTrue(presenter.interactor is RootInteractor)
            let view = try XCTUnwrap(presenter.view?.controller as? RootViewController)
            XCTAssertTrue(view.presenter === presenter)
            XCTAssertTrue(view.rootView.statusLabel.isHidden)
        }
        XCTAssertNil(window.rootViewController, "Building the presenter must not start the launch")
    }
}

final class CovJOnRootWireframeTests: XCTestCase {
    func testWindowRoutesOnAPrivateWindow() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let wireframe = RootWireframe()
        let splash = UIViewController()
        wireframe.showSplash(splashView: CovJOnRootView(), on: window)
        XCTAssertTrue(window.rootViewController is CovJOnRootView)
        wireframe.showSplash(splashView: nil, on: window)
        XCTAssertNil(window.rootViewController)
        window.rootViewController = splash

        wireframe.showBroken(on: window)
        XCTAssertEqual(window.backgroundColor, .clear)

        wireframe.showMain(on: window)
        let navigation = try XCTUnwrap(window.rootViewController as? FearlessNavigationController)
        XCTAssertEqual(navigation.viewControllers.count, 1)

        wireframe.showOnboarding(on: window, with: try CovJOnOnboardingFixture.config())
        XCTAssertTrue(window.rootViewController is OnboardingStartViewController)
        window.rootViewController = nil
    }
}

final class CovJOnRootViewControllerTests: XCTestCase {
    func testStatusLabelFollowsTheState() throws {
        let controller = RootViewController(presenter: CovJOnRootPresenterSpy(), localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        controller.didReceive(state: .updating(message: "Opening"))
        XCTAssertEqual(controller.rootView.statusLabel.text, "Opening")
        XCTAssertFalse(controller.rootView.statusLabel.isHidden)
        controller.applyLocalization()
        controller.didReceive(state: .plain)
        XCTAssertNil(controller.rootView.statusLabel.text)
        XCTAssertTrue(controller.rootView.statusLabel.isHidden)
    }
}

final class CovJOnRootPresenterSpy: RootPresenterProtocol {
    var launches = 0
    func loadOnLaunch() { launches += 1 }
    func reload() {}
}
