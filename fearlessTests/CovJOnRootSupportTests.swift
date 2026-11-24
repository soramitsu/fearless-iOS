import XCTest
import UIKit
import CoreData
import RobinHood
import SoraFoundation
import SoraKeystore
@testable import fearless

final class CovJOnCoreDataService: CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol = CoreDataServiceConfiguration(
        modelURL: URL(fileURLWithPath: "/covj/none.momd"),
        storageType: .inMemory
    )
    let context: NSManagedObjectContext?
    let error: Error?
    init(context: NSManagedObjectContext?, error: Error? = nil) {
        self.context = context
        self.error = error
    }
    func performAsync(block: @escaping CoreDataContextInvocationBlock) { block(context, error) }
    func close() throws {}
    func drop() throws {}
}

final class CovJOnNoticeTracker: UpdateSecurityNoticeTracking {
    var records: [Bool] = []
    var isPending: Bool { false }
    func recordStartup(hadStoredWallets: Bool) { records.append(hadStoredWallets) }
    func acknowledge() {}
}

enum CovJOnStartViewName {
    static func of(_ view: StartView) -> String {
        switch view {
        case .pin: return "pin"
        case .pinSetup: return "pinSetup"
        case .login: return "login"
        case let .onboarding(config): return "onboarding:" + config.minVersion
        }
    }
}

final class CovJOnRootErrorTests: XCTestCase {
    func testStoragePreflightErrorsDescribeTheirEntity() {
        let cases: [(RootStoragePreflightError, String)] = [
            (.contextUnavailable, "Substrate storage opened without a managed object context"),
            (.persistentStoreCoordinatorUnavailable, "Substrate storage opened without a persistent store coordinator"),
            (.entityNameUnavailable, "Substrate storage contains an unnamed entity"),
            (.managedObjectClassNameUnavailable(entityName: "CDAsset"), "Substrate storage entity CDAsset has no managed object class"),
            (.managedObjectClassUnavailable(entityName: "CDAsset", className: "Gone"), "Substrate storage entity CDAsset cannot resolve class Gone"),
            (.invocationCapacityExhausted, "Substrate storage preflight is still blocked; retry after the current checks finish"),
            (
                .unexpectedManagedObjectClassIdentity(entityName: "CDAsset", expectedClassName: "A", actualClassName: "B"),
                "Substrate storage entity CDAsset resolves as B, expected A"
            )
        ]
        for (error, text) in cases {
            XCTAssertEqual(error.errorDescription, text)
        }
    }

    func testWalletOpeningAndStartViewErrorsDescribeThemselves() {
        XCTAssertEqual(RootSelectedWalletOpeningError.walletStoreUnavailable.errorDescription, "The stored wallet records could not be opened safely")
        XCTAssertEqual(
            RootSelectedWalletOpeningError.unsupportedWalletRequiresCompatibility.errorDescription,
            "The stored wallet requires a compatibility mapping"
        )
        XCTAssertEqual(
            RootSelectedWalletOpeningError.inconsistentStoreState.errorDescription,
            "The selected wallet result did not match the validated store state"
        )
        XCTAssertEqual(StartViewError.selectedWalletUnavailable.errorDescription, "The selected wallet store is unavailable")
        XCTAssertEqual(StartViewError.selectedWalletMissing.errorDescription, "The selected wallet store did not provide its validated wallet")
        XCTAssertEqual(StartViewError.unsupportedWalletRequiresCompatibility.errorDescription, "The stored wallet requires a compatibility mapping")
        XCTAssertEqual(StartViewError.startupRouteValidationUnavailable.errorDescription, "The validated startup route is unavailable")
    }
}

final class CovJOnStoragePreflightTests: XCTestCase {
    private func run(_ service: CovJOnCoreDataService) -> Result<Void, Error>? {
        var outcome: Result<Void, Error>?
        RootCoreDataStoragePreflight(databaseService: service).preflight { outcome = $0 }
        return outcome
    }

    private func entity(_ name: String, className: String, abstract: Bool = false) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = className
        entity.isAbstract = abstract
        let attribute = NSAttributeDescription()
        attribute.name = "value"
        attribute.attributeType = .stringAttributeType
        attribute.isOptional = true
        entity.properties = [attribute]
        return entity
    }

    private func context(entities: [NSEntityDescription]) throws -> NSManagedObjectContext {
        let model = NSManagedObjectModel()
        model.entities = entities
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

    func testServiceErrorsAndMissingContextOrCoordinatorFail() throws {
        guard case let .failure(serviceError)? = run(CovJOnCoreDataService(context: nil, error: CovJError("open"))) else {
            return XCTFail("Expected the service error")
        }
        XCTAssertEqual(serviceError as? CovJError, CovJError("open"))

        guard case let .failure(missing)? = run(CovJOnCoreDataService(context: nil)) else {
            return XCTFail("Expected a missing context")
        }
        XCTAssertEqual(missing.localizedDescription, RootStoragePreflightError.contextUnavailable.errorDescription)

        let orphan = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        guard case let .failure(noCoordinator)? = run(CovJOnCoreDataService(context: orphan)) else {
            return XCTFail("Expected a missing coordinator")
        }
        XCTAssertEqual(noCoordinator.localizedDescription, RootStoragePreflightError.persistentStoreCoordinatorUnavailable.errorDescription)
    }

    func testAbstractEntitiesAreSkippedAndConcreteOnesQueried() throws {
        let plain = NSStringFromClass(NSManagedObject.self)
        let context = try context(entities: [
            entity("CovJOnConcrete", className: plain),
            entity("CovJOnAbstract", className: plain, abstract: true)
        ])
        guard case .success? = run(CovJOnCoreDataService(context: context)) else {
            return XCTFail("A store whose classes resolve must pass")
        }
    }

    func testUnresolvableManagedObjectClassFailsClosed() throws {
        let context = try context(entities: [entity("CovJOnGhost", className: "CovJOnNoSuchManagedObjectClass")])
        guard case let .failure(error)? = run(CovJOnCoreDataService(context: context)) else {
            return XCTFail("Expected an unresolvable class")
        }
        XCTAssertEqual(
            error.localizedDescription,
            RootStoragePreflightError.managedObjectClassUnavailable(
                entityName: "CovJOnGhost",
                className: "CovJOnNoSuchManagedObjectClass"
            ).errorDescription
        )
    }
}

final class CovJOnStartViewHelperTests: XCTestCase {
    func testValidatedRoutesRecordWhetherWalletsExisted() throws {
        let config = try CovJOnOnboardingFixture.config(minVersion: "6.0.0")
        let cases: [(RootStartupRouteValidation, OnboardingConfigWrapper?, String, [Bool])] = [
            (.empty, nil, "login", [false]),
            (.ready(pincodeAvailable: true), nil, "pin", [true]),
            (.ready(pincodeAvailable: false), nil, "pinSetup", [true]),
            (.ready(pincodeAvailable: false), config, "onboarding:6.0.0", [true]),
            (.unsupportedOnlyWithoutPincode, nil, "login", [true]),
            (.unavailableWithoutPincode, nil, "login", [])
        ]
        for (validation, onboarding, expected, records) in cases {
            let store = RootStartupRouteValidationStore()
            let tracker = CovJOnNoticeTracker()
            let helper = StartViewHelper(
                keystore: InMemoryKeychain(),
                selectedWalletSettingsProvider: {
                    SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
                },
                userDefaultsStorage: InMemorySettingsManager(),
                startupRouteValidationStore: store,
                updateSecurityNotice: tracker
            )
            store.replace(with: validation)
            XCTAssertEqual(CovJOnStartViewName.of(try helper.startView(onboardingConfig: onboarding)), expected)
            XCTAssertEqual(tracker.records, records)
            XCTAssertThrowsError(try helper.startView(onboardingConfig: nil), "A validation is used once") { error in
                XCTAssertEqual(error as? StartViewError, .startupRouteValidationUnavailable)
            }
        }
    }

    func testEmptyWalletStoreShowsOnboardingWhenConfiguredOtherwiseLogin() throws {
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        var finished = false
        settings.setup(runningCompletionIn: .main) { _ in finished = true }
        XCTAssertTrue(CovJWait.until(timeout: 5) { finished })
        XCTAssertEqual(settings.storeState, .empty)
        let helper = StartViewHelper(
            keystore: InMemoryKeychain(),
            selectedWalletSettings: settings,
            userDefaultsStorage: InMemorySettingsManager()
        )
        let config = try CovJOnOnboardingFixture.config(minVersion: "7.0.0")
        XCTAssertEqual(CovJOnStartViewName.of(try helper.startView(onboardingConfig: config)), "onboarding:7.0.0")
        XCTAssertEqual(CovJOnStartViewName.of(try helper.startView(onboardingConfig: nil)), "login")
    }
}

final class CovJOnStartupRecoveryControllerTests: XCTestCase {
    private func present(
        phase: RootSetupPhase,
        code: RootSetupIncidentCode,
        tapping action: StartupRecoveryViewModel.Action
    ) throws -> [StartupRecoveryViewModel.Action] {
        let host = UIViewController()
        let window = try CovJViewFixture.host(host)
        defer {
            host.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        var handled: [StartupRecoveryViewModel.Action] = []
        let failure = RootSetupFailure(phase: phase, incidentCode: code, elapsedTime: 0, recoveryAction: .retry)
        let model = StartupRecoveryViewModel(failure: failure, consecutiveFailures: 2)
        XCTAssertTrue(model.actions.contains(action))
        let controller = StartupRecoveryViewController(model: model) { handled.append($0) }
        host.present(controller, animated: false)
        controller.view.layoutIfNeeded()
        let layout = try XCTUnwrap(controller.view as? StartupRecoveryViewLayout)
        let title = action.localizedTitle(locale: controller.model.locale)
        let button = try XCTUnwrap(layout.stack.arrangedSubviews.compactMap { $0 as? UIButton }.first {
            $0.configuration?.title == title
        })
        button.sendActions(for: .touchUpInside)
        XCTAssertTrue(CovJWait.until(timeout: 5) { !handled.isEmpty })
        XCTAssertNil(host.presentedViewController)
        return handled
    }

    func testFreshNetworkDataAndEnglishActionsCloseThenReport() throws {
        XCTAssertEqual(try present(phase: .substrateMigration, code: .substrateMigrationFailed, tapping: .freshNetworkData), [.freshNetworkData])
        XCTAssertEqual(try present(phase: .languageMigration, code: .languageMigrationFailed, tapping: .continueInEnglish), [.continueInEnglish])
    }

    func testLocalizationFallsBackToTheSharedLanguageAndActionTitlesUseIt() throws {
        let failure = RootSetupFailure(phase: .selectedWalletOpening, incidentCode: .walletRecordRejected, elapsedTime: 0, recoveryAction: .restoreWalletAccess)
        let controller = StartupRecoveryViewController(model: StartupRecoveryViewModel(failure: failure, consecutiveFailures: 1)) { _ in }
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        controller.localizationManager = nil
        controller.applyLocalization()
        let layout = try XCTUnwrap(controller.view as? StartupRecoveryViewLayout)
        let labels = layout.stack.arrangedSubviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.first?.text, controller.model.title)
        XCTAssertTrue(controller.model.actions.contains(.restoreWalletAccess))
        let shared = LocalizationManager.shared.selectedLocalization
        XCTAssertEqual(StartupRecoveryViewModel.Action.retry.title, StartupRecoveryViewModel.Action.retry.localizedTitle(locale: shared))
        XCTAssertEqual(StartupRecoveryViewModel.Action.help.title, RecoveryText.string("help"))
    }
}

final class CovJOnSceneDelegateTests: XCTestCase {
    func testDisconnectReleasesTheWindowAndEmptyURLDeliveryIsHarmless() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first)
        let delegate = SceneDelegate()
        delegate.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        delegate.scene(scene, openURLContexts: [])
        XCTAssertNotNil(delegate.window)
        delegate.sceneWillEnterForeground(scene)
        delegate.sceneDidDisconnect(scene)
        XCTAssertNil(delegate.window)
    }
}
