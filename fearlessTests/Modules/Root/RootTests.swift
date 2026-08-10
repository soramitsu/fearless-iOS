import XCTest
import Foundation
import CoreData
@testable import fearless
import Cuckoo
import RobinHood
import SoraKeystore
import SoraFoundation
import simd
import SQLite3

class RootTests: XCTestCase {
    func testWalletConnectGroupResolverUsesProductionEntitlementForReleaseBundle() {
        XCTAssertEqual(
            WalletConnectGroupIdentifierResolver.resolve(
                bundleIdentifier: "jp.co.soramitsu.fearlesswallet"
            ),
            "group.jp.co.soramitsu.fearlesswallet"
        )
    }

    func testWalletConnectGroupResolverUsesDevelopmentEntitlementForDevBundle() {
        XCTAssertEqual(
            WalletConnectGroupIdentifierResolver.resolve(
                bundleIdentifier: "jp.co.soramitsu.fearlesswallet.dev"
            ),
            "group.jp.co.soramitsu.fearlesswallet.walletconnect"
        )
    }

    func testWalletConnectGroupResolverRejectsUnsupportedApplicationIdentities() {
        let unsupportedIdentifiers: [String?] = [
            nil,
            "",
            "jp.co.soramitsu.fearless",
            "jp.co.soramitsu.fearlesswallet.debug",
            "jp.co.soramitsu.fearlesswallet.dev.attacker",
            "evil.jp.co.soramitsu.fearlesswallet"
        ]

        for identifier in unsupportedIdentifiers {
            XCTAssertNil(
                WalletConnectGroupIdentifierResolver.resolve(
                    bundleIdentifier: identifier
                ),
                "Unexpected WalletConnect group for \(identifier ?? "nil")"
            )
        }
    }

    func testHostedUnitTestsUseIsolatedApplicationLaunch() {
        XCTAssertTrue(
            ProcessInfo.processInfo.arguments.contains("-UNITTEST"),
            "Hosted unit tests must not launch the production startup path or open persistent stores"
        )
    }

    func testCoreDataPreflightForwardsStoreOpenError() throws {
        let configuration = try makeSubstrateInMemoryConfiguration()
        let preflight = RootCoreDataStoragePreflight(
            databaseService: FailingCoreDataService(
                configuration: configuration,
                error: RootSetupTestError.substrateStorageOpenFailed
            )
        )

        XCTAssertThrowsError(try performStoragePreflight(preflight).get()) { error in
            guard case RootSetupTestError.substrateStorageOpenFailed = error else {
                return XCTFail("Unexpected forwarded open error: \(error)")
            }
        }
    }

    func testCoreDataPreflightRejectsUnresolvableEntityClassBeforeFetch() throws {
        let entity = NSEntityDescription()
        entity.name = "BrokenSubstrateEntity"
        entity.managedObjectClassName = "MissingSubstrateManagedObjectClass"

        let model = NSManagedObjectModel()
        model.entities = [entity]

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let preflight = RootCoreDataStoragePreflight(
            databaseService: ContextProvidingCoreDataService(
                configuration: try makeSubstrateInMemoryConfiguration(),
                context: context
            )
        )

        XCTAssertThrowsError(try performStoragePreflight(preflight).get()) { error in
            guard
                let preflightError = error as? RootStoragePreflightError,
                case let .managedObjectClassUnavailable(entityName, className) =
                preflightError
            else {
                return XCTFail("Expected a class-resolution failure, got \(error)")
            }

            XCTAssertEqual(entityName, "BrokenSubstrateEntity")
            XCTAssertEqual(className, "MissingSubstrateManagedObjectClass")
        }
    }

    func testCoreDataPreflightQueriesObjectIdsWithoutDecodingCorruptTransformables() throws {
        let entity = NSEntityDescription()
        entity.name = "PreflightArchive"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .transformableAttributeType
        payload.attributeValueClassName = NSStringFromClass(NSData.self)
        payload.valueTransformerName =
            NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
        payload.isOptional = true
        entity.properties = [payload]

        let model = NSManagedObjectModel()
        model.entities = [entity]

        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "RootStoragePreflight-\(UUID().uuidString)",
            isDirectory: true
        )
        let storeURL = directoryURL.appendingPathComponent("Preflight.sqlite")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let writerCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        let storeOptions: [AnyHashable: Any] = [
            NSSQLitePragmasOption: ["journal_mode": "DELETE"]
        ]
        let writerStore = try writerCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: storeOptions
        )
        let writerContext = NSManagedObjectContext(
            concurrencyType: .mainQueueConcurrencyType
        )
        writerContext.persistentStoreCoordinator = writerCoordinator
        let object = NSManagedObject(entity: entity, insertInto: writerContext)
        object.setValue(Data("valid archive".utf8), forKey: payload.name)
        try writerContext.save()
        writerContext.reset()
        try writerCoordinator.remove(writerStore)

        XCTAssertEqual(
            try executeSQLiteUpdate(
                "UPDATE ZPREFLIGHTARCHIVE SET ZPAYLOAD = X'00FF00'",
                at: storeURL
            ),
            1
        )

        let readerCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        let readerStore = try readerCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: storeOptions
        )
        defer {
            try? readerCoordinator.remove(readerStore)
        }
        let readerContext = NSManagedObjectContext(
            concurrencyType: .mainQueueConcurrencyType
        )
        readerContext.persistentStoreCoordinator = readerCoordinator
        let preflight = RootCoreDataStoragePreflight(
            databaseService: ContextProvidingCoreDataService(
                configuration: try makeSubstrateInMemoryConfiguration(),
                context: readerContext
            )
        )

        XCTAssertNoThrow(try performStoragePreflight(preflight).get())
        XCTAssertFalse(readerContext.hasChanges)
    }

    func testUserStorageFacadeMissingModelReturnsControlledFailure() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MissingUserModel-\(UUID().uuidString)",
            isDirectory: true
        )
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let facade = UserDataStorageFacade(
            modelURL: nil,
            databaseDirectory: directoryURL
        )
        let completionExpectation = expectation(
            description: "missing User model returns an error"
        )

        facade.databaseService.performAsync { context, error in
            XCTAssertNil(context)

            guard
                let serviceError = error as? CoreDataServiceError,
                case .modelInitializationFailed = serviceError
            else {
                XCTFail("Expected modelInitializationFailed, got \(String(describing: error))")
                completionExpectation.fulfill()
                return
            }

            completionExpectation.fulfill()
        }

        wait(
            for: [completionExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }

    func testSubstrateStorageFacadeMissingModelFailsPreflightWithoutTrap() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MissingSubstrateModel-\(UUID().uuidString)",
            isDirectory: true
        )
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let facade = SubstrateDataStorageFacade(
            modelURL: nil,
            databaseDirectory: directoryURL,
            databaseName: "MissingSubstrateModel.sqlite"
        )
        let preflight = RootCoreDataStoragePreflight(
            databaseService: facade.databaseService
        )

        XCTAssertThrowsError(try performStoragePreflight(preflight).get()) { error in
            guard
                let serviceError = error as? CoreDataServiceError,
                case .modelInitializationFailed = serviceError
            else {
                return XCTFail("Expected modelInitializationFailed, got \(error)")
            }
        }
    }

    func testStartViewHelperDoesNotResolveWalletSettingsDuringConstruction() {
        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        var providerInvocationCount = 0
        let helper = StartViewHelper(
            keystore: InMemoryKeychain(),
            selectedWalletSettingsProvider: {
                providerInvocationCount += 1
                return settings
            },
            userDefaultsStorage: InMemorySettingsManager()
        )

        XCTAssertEqual(providerInvocationCount, 0)

        _ = helper.startView(onboardingConfig: nil)

        XCTAssertEqual(providerInvocationCount, 1)
    }

    func testMigrationFailureDoesNotResolveStorePreflightRegistryOrWalletSettings() {
        let recorder = RootSetupEventRecorder()
        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: recorder,
            result: .success(nil)
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()
        let failureExpectation = expectation(
            description: "migration failure is reported"
        )

        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didFailSetup(any()).then { _ in
                failureExpectation.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: {
                recorder.record(.storagePreflightProvider)
                return ImmediateRootStoragePreflight(result: .success(()))
            },
            settingsProvider: {
                recorder.record(.walletSettingsProvider)
                return settings
            },
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [
                rootMigrationStep(RecordingRootMigrator(
                    recorder: recorder,
                    error: RootSetupTestError.migrationFailed
                ))
            ],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            )
        )
        interactor.presenter = output

        interactor.setup(runMigrations: true)

        wait(
            for: [failureExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(recorder.snapshot, [.migration])
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()
        verify(output, times(0)).didUpdateSetup(equal(to: .ready))
        verify(output, times(1)).didFailSetup(any())
    }

    func testMigrationFailureBlocksNoMigrationBypassAndRequiredRetryRerunsMigration() {
        let recorder = RootSetupEventRecorder()
        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: recorder,
            result: .success(nil)
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()
        let firstFailureExpectation = expectation(
            description: "first migration attempt fails"
        )
        let blockedBypassExpectation = expectation(
            description: "no-migration retry cannot bypass failed migration"
        )
        let retryCompletionExpectation = expectation(
            description: "migration retry completes setup"
        )
        var failureCallbackCount = 0
        let migrator = SequencedRootMigrator(
            recorder: recorder,
            results: [
                .failure(RootSetupTestError.migrationFailed),
                .success(())
            ]
        )

        stub(chainRegistry) { stub in
            stub.performColdBoot().then {
                recorder.record(.coldBoot)
            }
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didFailSetup(any()).then { _ in
                failureCallbackCount += 1

                if failureCallbackCount == 1 {
                    firstFailureExpectation.fulfill()
                } else if failureCallbackCount == 2 {
                    blockedBypassExpectation.fulfill()
                }
            }
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                retryCompletionExpectation.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: {
                recorder.record(.storagePreflightProvider)
                return RecordingRootStoragePreflight(
                    recorder: recorder,
                    result: .success(())
                )
            },
            settingsProvider: {
                recorder.record(.walletSettingsProvider)
                return settings
            },
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [rootMigrationStep(migrator)],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            )
        )
        interactor.presenter = output

        interactor.setup(runMigrations: true)
        wait(
            for: [firstFailureExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(recorder.snapshot, [.migration])

        interactor.setup(runMigrations: false)
        wait(
            for: [blockedBypassExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(recorder.snapshot, [.migration])

        interactor.setup(runMigrations: true)
        wait(
            for: [retryCompletionExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(
            recorder.snapshot,
            [
                .migration,
                .migration,
                .storagePreflightProvider,
                .storagePreflight,
                .chainRegistry,
                .walletSettingsProvider,
                .walletSetup,
                .coldBoot
            ]
        )
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(1)).performColdBoot()
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
        verify(output, times(2)).didFailSetup(any())
    }

    func testMigrationCompletingAfterSixtySecondsAutoContinuesWithoutRetry() {
        let recorder = RootSetupEventRecorder()
        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: recorder,
            result: .success(nil)
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()
        let migrationStartedExpectation = expectation(
            description: "migration attempt starts"
        )
        let migrationThresholdScheduledExpectation = expectation(
            description: "migration slow threshold is scheduled"
        )
        let slowExpectation = expectation(
            description: "migration reports a nonterminal slow state"
        )
        let completionExpectation = expectation(
            description: "original migration completes setup"
        )
        let deadlineScheduler = ManualRootSetupDeadlineScheduler(
            scheduledExpectations: [migrationThresholdScheduledExpectation]
        )
        let migrator = BlockingRootMigrator(
            recorder: recorder,
            startedExpectation: migrationStartedExpectation
        )
        let clock = ControllableRootMonotonicClock(now: 1000)

        stub(chainRegistry) { stub in
            stub.performColdBoot().then {
                recorder.record(.coldBoot)
            }
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didUpdateSetup(
                equal(to: .slow(.userStorageMigration, elapsedTime: 60))
            ).then { _ in
                slowExpectation.fulfill()
            }
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                completionExpectation.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: {
                recorder.record(.storagePreflightProvider)
                return RecordingRootStoragePreflight(
                    recorder: recorder,
                    result: .success(())
                )
            },
            settingsProvider: {
                recorder.record(.walletSettingsProvider)
                return settings
            },
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [rootMigrationStep(migrator)],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            ),
            migrationDeadline: 60,
            setupDeadline: 15,
            setupDeadlineScheduler: deadlineScheduler.schedule,
            monotonicTimeProvider: clock.currentTime
        )
        interactor.presenter = output
        defer {
            migrator.release()
        }

        interactor.setup(runMigrations: true)
        wait(
            for: [
                migrationStartedExpectation,
                migrationThresholdScheduledExpectation
            ],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(deadlineScheduler.delays, [60])
        clock.advance(by: 60)
        deadlineScheduler.fire(at: 0)
        wait(for: [slowExpectation], timeout: Constants.defaultExpectationDuration)

        // Reloads and repeated Retry taps while the original operation is
        // active must coalesce behind the same writer.
        interactor.setup(runMigrations: false)
        interactor.setup(runMigrations: true)

        XCTAssertEqual(migrator.invocationCount, 1)
        XCTAssertEqual(migrator.maximumConcurrentInvocationCount, 1)
        XCTAssertEqual(deadlineScheduler.delays, [60])
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()

        migrator.release()
        wait(
            for: [completionExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(
            recorder.snapshot,
            [
                .migration,
                .storagePreflightProvider,
                .storagePreflight,
                .chainRegistry,
                .walletSettingsProvider,
                .walletSetup,
                .coldBoot
            ]
        )
        XCTAssertEqual(migrator.invocationCount, 1)
        XCTAssertEqual(migrator.maximumConcurrentInvocationCount, 1)
        XCTAssertEqual(deadlineScheduler.delays, [60, 15, 15])
        verify(output, times(0)).didFailSetup(any())
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(1)).performColdBoot()
    }

    func testPreflightFailureDoesNotResolveRegistryOrWalletSettings() {
        let recorder = RootSetupEventRecorder()
        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: recorder,
            result: .success(nil)
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()
        let failureExpectation = expectation(
            description: "preflight failure is reported"
        )

        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didFailSetup(any()).then { _ in
                failureExpectation.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: {
                recorder.record(.storagePreflightProvider)
                return RecordingRootStoragePreflight(
                    recorder: recorder,
                    result: .failure(RootSetupTestError.substrateStorageOpenFailed)
                )
            },
            settingsProvider: {
                recorder.record(.walletSettingsProvider)
                return settings
            },
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [
                rootMigrationStep(RecordingRootMigrator(recorder: recorder))
            ],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            )
        )
        interactor.presenter = output

        interactor.setup(runMigrations: true)

        wait(
            for: [failureExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(
            recorder.snapshot,
            [.migration, .storagePreflightProvider, .storagePreflight]
        )
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()
        verify(output, times(0)).didUpdateSetup(equal(to: .ready))
        verify(output, times(1)).didFailSetup(any())
    }

    func testWalletFailureRetryDoesNotRerunMigrationsAgainstResolvedStores() {
        let recorder = RootSetupEventRecorder()
        let settings = SequencedRootSelectedWalletSettings(
            recorder: recorder,
            results: [
                .failure(RootSetupTestError.walletRepositoryFailed),
                .success(nil)
            ]
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()
        let firstFailureExpectation = expectation(
            description: "wallet setup fails after migrations"
        )
        let retryCompletionExpectation = expectation(
            description: "wallet setup retry completes"
        )

        stub(chainRegistry) { stub in
            stub.performColdBoot().then {
                recorder.record(.coldBoot)
            }
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didFailSetup(any()).then { _ in
                firstFailureExpectation.fulfill()
            }
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                retryCompletionExpectation.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: {
                recorder.record(.storagePreflightProvider)
                return RecordingRootStoragePreflight(
                    recorder: recorder,
                    result: .success(())
                )
            },
            settingsProvider: {
                recorder.record(.walletSettingsProvider)
                return settings
            },
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [
                rootMigrationStep(RecordingRootMigrator(recorder: recorder))
            ],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            )
        )
        interactor.presenter = output

        interactor.setup(runMigrations: false)
        wait(
            for: [firstFailureExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(
            recorder.snapshot,
            [
                .storagePreflightProvider,
                .storagePreflight,
                .chainRegistry,
                .walletSettingsProvider,
                .walletSetup
            ]
        )

        interactor.setup(runMigrations: true)
        wait(
            for: [retryCompletionExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(
            recorder.snapshot,
            [
                .storagePreflightProvider,
                .storagePreflight,
                .chainRegistry,
                .walletSettingsProvider,
                .walletSetup,
                .storagePreflightProvider,
                .storagePreflight,
                .walletSetup,
                .coldBoot
            ]
        )
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(1)).performColdBoot()
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
        verify(output, times(1)).didFailSetup(any())
    }

    func testMigrationFailureDoesNotLoadWalletOrRouteAndPreservesPincode() throws {
        // given

        let recorder = RootSetupEventRecorder()
        let storageFacade = RecordingUserDataStorageTestFacade(recorder: recorder)
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        let keystore = InMemoryKeychain()
        let expectedPincode = "123456"
        try keystore.saveKey(
            Data(expectedPincode.utf8),
            with: KeystoreTag.pincode.rawValue
        )

        let migrator = RecordingRootMigrator(recorder: recorder, error: RootSetupTestError.migrationFailed)
        let wireframe = MockRootWireframeProtocol()
        let alertController = AlertCapturingViewController()
        let readinessReporter = RecordingRootStartupReadinessReporter()
        let failureExpectation = XCTestExpectation(description: "setup failure is presented")

        alertController.onPresent = { presentedController in
            XCTAssertTrue(presentedController is UIAlertController)
            failureExpectation.fulfill()
        }

        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).thenDoNothing()
        }

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: InMemorySettingsManager(),
            migrationSteps: [rootMigrationStep(migrator)],
            view: alertController,
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return ChainRegistryFacade.sharedRegistry
            },
            storagePreflightProvider: {
                RecordingRootStoragePreflight(
                    recorder: recorder,
                    result: .success(())
                )
            },
            startupReadinessReporter: readinessReporter
        )

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [failureExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(recorder.snapshot, [.migration])
        XCTAssertEqual(readinessReporter.readyCount, 0)
        XCTAssertEqual(readinessReporter.failureCount, 1)
        XCTAssertTrue(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
        verify(wireframe, times(0)).showLocalAuthentication(on: any())
        verify(wireframe, times(0)).showPincodeSetup(on: any())
        verify(wireframe, times(0)).showMain(on: any())
        verify(wireframe, times(0)).showBroken(on: any())
        verify(wireframe, times(0)).showOnboarding(on: any(), with: any())
    }

    func testSubstratePreflightFailureDoesNotCreateRegistryOrOpenWalletAndPreservesData() throws {
        let recorder = RootSetupEventRecorder()
        let storageFacade = RecordingUserDataStorageTestFacade(recorder: recorder)
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        try insertTonOnlyWallet(in: storageFacade)
        let walletBefore = try tonOnlyWalletSnapshot(in: storageFacade)
        recorder.reset()

        let keystore = InMemoryKeychain()
        try keystore.saveKey(
            Data("123456".utf8),
            with: KeystoreTag.pincode.rawValue
        )

        let chainRegistry = MockChainRegistryProtocol()
        let wireframe = MockRootWireframeProtocol()
        let alertController = AlertCapturingViewController()
        let failureExpectation = expectation(
            description: "Substrate preflight failure is presented"
        )

        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).thenDoNothing()
        }
        alertController.onPresent = { presentedController in
            XCTAssertTrue(presentedController is UIAlertController)
            failureExpectation.fulfill()
        }

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: InMemorySettingsManager(),
            migrationSteps: [
                rootMigrationStep(RecordingRootMigrator(recorder: recorder))
            ],
            view: alertController,
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: {
                RecordingRootStoragePreflight(
                    recorder: recorder,
                    result: .failure(RootSetupTestError.substrateStorageOpenFailed)
                )
            }
        )

        presenter.loadOnLaunch()

        wait(for: [failureExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(recorder.snapshot, [.migration, .storagePreflight])
        XCTAssertEqual(try tonOnlyWalletSnapshot(in: storageFacade), walletBefore)
        XCTAssertTrue(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()
        verify(wireframe, times(0)).showLocalAuthentication(on: any())
        verify(wireframe, times(0)).showPincodeSetup(on: any())
        verify(wireframe, times(0)).showMain(on: any())
        verify(wireframe, times(0)).showBroken(on: any())
        verify(wireframe, times(0)).showOnboarding(on: any(), with: any())
    }

    func testWalletRepositoryFailureDoesNotBootOrRouteAndPreservesPincode() throws {
        // given

        let storageFacade = FailingUserDataStorageTestFacade(
            error: RootSetupTestError.walletRepositoryFailed
        )
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        let keystore = InMemoryKeychain()
        try keystore.saveKey(
            Data("123456".utf8),
            with: KeystoreTag.pincode.rawValue
        )

        let chainRegistry = MockChainRegistryProtocol()
        let wireframe = MockRootWireframeProtocol()
        let alertController = AlertCapturingViewController()
        let failureExpectation = XCTestExpectation(description: "wallet-load failure is presented")
        let onboardingService = StubOnboardingService(
            result: .success(Self.makeOnboardingPlatform())
        )

        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).thenDoNothing()
        }
        alertController.onPresent = { presentedController in
            XCTAssertTrue(presentedController is UIAlertController)
            failureExpectation.fulfill()
        }

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: InMemorySettingsManager(),
            onboardingService: onboardingService,
            view: alertController,
            chainRegistryProvider: { chainRegistry }
        )

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [failureExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertTrue(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
        XCTAssertEqual(settings.storeState, .unavailable)
        XCTAssertEqual(onboardingService.fetchCallCount, 0)
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()
        verify(wireframe, times(0)).showLocalAuthentication(on: any())
        verify(wireframe, times(0)).showPincodeSetup(on: any())
        verify(wireframe, times(0)).showMain(on: any())
        verify(wireframe, times(0)).showBroken(on: any())
        verify(wireframe, times(0)).showOnboarding(on: any(), with: any())
    }

    func testRepeatedSetupCallsCoalesceAndStaleWalletCallbacksCannotMutateReadyState() {
        let firstRequestStarted = expectation(description: "wallet request starts")
        let setupCompleted = expectation(description: "setup completes")
        let staleSuccessDelivered = expectation(description: "stale success callback returns")
        let staleFailureDelivered = expectation(description: "stale failure callback returns")
        let settings = ControllableRootSelectedWalletSettings(
            requestStartedExpectations: [firstRequestStarted]
        )
        let recorder = RootGenerationEventRecorder()
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()

        stub(chainRegistry) { stub in
            stub.performHotBoot().then {
                recorder.record(.hotBoot)
            }
            stub.performColdBoot().then {
                recorder.record(.coldBoot)
            }
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                recorder.record(.completed)
                setupCompleted.fulfill()
            }
            stub.didFailSetup(any()).then { _ in
                recorder.record(.failed)
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: { chainRegistry },
            storagePreflightProvider: {
                ImmediateRootStoragePreflight(result: .success(()))
            },
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            )
        )
        interactor.presenter = output

        interactor.setup(runMigrations: false)
        wait(for: [firstRequestStarted], timeout: Constants.defaultExpectationDuration)

        for index in 0 ..< 20 {
            interactor.setup(runMigrations: index.isMultiple(of: 2))
        }

        let coalescedCallsDrained = expectation(
            description: "repeated calls reach the setup queue"
        )
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            coalescedCallsDrained.fulfill()
        }
        wait(
            for: [coalescedCallsDrained],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(settings.requestCount, 1)

        settings.resolveRequest(
            at: 0,
            with: .success(nil)
        )
        wait(for: [setupCompleted], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(recorder.snapshot, [.coldBoot, .completed])
        XCTAssertEqual(recorder.routeState, .completed)

        settings.resolveRequest(
            at: 0,
            with: .success(AccountGenerator.generateMetaAccount()),
            deliveryExpectation: staleSuccessDelivered
        )
        settings.resolveRequest(
            at: 0,
            with: .failure(RootSetupTestError.staleWalletLoadFailed),
            deliveryExpectation: staleFailureDelivered
        )
        wait(
            for: [staleSuccessDelivered, staleFailureDelivered],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(recorder.snapshot, [.coldBoot, .completed])
        XCTAssertEqual(recorder.routeState, .completed)
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(1)).performColdBoot()
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
        verify(output, times(0)).didFailSetup(any())
    }

    func testPreflightCompletingAfterFifteenSecondsAutoContinuesWithoutRetry() {
        let requestStarted = expectation(description: "preflight starts")
        let slowExpectation = expectation(description: "preflight reports slow")
        let setupCompleted = expectation(description: "late preflight completes setup")
        let preflight = ControllableRootStoragePreflight(
            requestStartedExpectations: [requestStarted]
        )
        let deadlineScheduler = ManualRootSetupDeadlineScheduler()
        let clock = ControllableRootMonotonicClock(now: 500)
        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: RootSetupEventRecorder(),
            result: .success(nil)
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()

        stub(chainRegistry) { stub in
            stub.performColdBoot().thenDoNothing()
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didUpdateSetup(
                equal(to: .slow(.substratePreflight, elapsedTime: 15))
            ).then { _ in
                slowExpectation.fulfill()
            }
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                setupCompleted.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: { chainRegistry },
            storagePreflightProvider: { preflight },
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            ),
            setupDeadline: 15,
            setupDeadlineScheduler: deadlineScheduler.schedule,
            monotonicTimeProvider: clock.currentTime
        )
        interactor.presenter = output

        interactor.setup(runMigrations: false)
        wait(
            for: [requestStarted],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(deadlineScheduler.delays, [15])
        clock.advance(by: 15)
        deadlineScheduler.fire(at: 0)
        wait(for: [slowExpectation], timeout: Constants.defaultExpectationDuration)

        // A user tap after the slow threshold must not create a second open.
        interactor.setup(runMigrations: false)
        preflight.resolveRequest(
            at: 0,
            with: .success(())
        )

        wait(
            for: [setupCompleted],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(preflight.requestCount, 1)
        XCTAssertEqual(deadlineScheduler.delays, [15, 15])

        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(1)).performColdBoot()
        verify(output, times(0)).didFailSetup(any())
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
    }

    func testSynchronouslyBlockedPreflightSlowStateDoesNotFailAndLateSuccessWinsOnce() {
        let blockedRequestStarted = expectation(
            description: "blocking preflight starts"
        )
        let slowExpectation = expectation(
            description: "blocking preflight reports slow"
        )
        slowExpectation.assertForOverFulfill = true
        let setupCompleted = expectation(
            description: "original preflight completes after release"
        )
        setupCompleted.assertForOverFulfill = true
        let lateCallbacksDelivered = expectation(
            description: "blocked preflight delivers late success and failure"
        )
        let blockedPreflight = SynchronouslyBlockingRootStoragePreflight(
            requestStartedExpectation: blockedRequestStarted,
            lateCallbacksDeliveredExpectation: lateCallbacksDelivered
        )
        defer {
            blockedPreflight.release()
        }

        let preflightSequence = RootStoragePreflightSequence(
            preflights: [
                blockedPreflight,
                ImmediateRootStoragePreflight(result: .success(()))
            ]
        )
        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: RootSetupEventRecorder(),
            result: .success(nil)
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()

        stub(chainRegistry) { stub in
            stub.performColdBoot().thenDoNothing()
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).then { state in
                XCTAssertTrue(Thread.isMainThread)
                switch state {
                case .slow(.substratePreflight, _):
                    slowExpectation.fulfill()
                case .ready:
                    setupCompleted.fulfill()
                case .running, .slow, .failed:
                    break
                }
            }
        }

        let setupDeadline: TimeInterval = 0.25
        let interactor = RootInteractor(
            chainRegistryProvider: { chainRegistry },
            storagePreflightProvider: preflightSequence.next,
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            ),
            setupDeadline: setupDeadline
        )
        interactor.presenter = output

        interactor.setup(runMigrations: false)
        wait(
            for: [blockedRequestStarted],
            timeout: Constants.defaultExpectationDuration
        )

        wait(
            for: [slowExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        // Repeated setup calls remain coalesced while the original call is
        // synchronously blocked.
        interactor.setup(runMigrations: false)
        blockedPreflight.release()
        wait(
            for: [lateCallbacksDelivered, setupCompleted],
            timeout: Constants.defaultExpectationDuration
        )

        let pendingDeadlinesDrained = expectation(
            description: "stale slow callbacks have had time to drain"
        )
        DispatchQueue.global().asyncAfter(
            deadline: .now() + setupDeadline * 2
        ) {
            pendingDeadlinesDrained.fulfill()
        }
        wait(
            for: [pendingDeadlinesDrained],
            timeout: Constants.defaultExpectationDuration
        )

        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(1)).performColdBoot()
        verify(output, times(0)).didFailSetup(any())
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
    }

    func testProtectedDataUnavailableWaitsWithoutStorageAndResumesAutomatically() {
        let recorder = RootSetupEventRecorder()
        let protectedDataObserverRegistered = expectation(
            description: "protected-data observer is registered"
        )
        let monitor = ControllableRootProtectedDataAvailabilityMonitor(
            isAvailable: false,
            firstObservationExpectation: protectedDataObserverRegistered
        )
        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: recorder,
            result: .success(nil)
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()
        let completionExpectation = expectation(
            description: "unlock resumes and completes setup"
        )

        stub(chainRegistry) { stub in
            stub.performColdBoot().then {
                recorder.record(.coldBoot)
            }
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                completionExpectation.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: {
                recorder.record(.storagePreflightProvider)
                return RecordingRootStoragePreflight(
                    recorder: recorder,
                    result: .success(())
                )
            },
            settingsProvider: {
                recorder.record(.walletSettingsProvider)
                return settings
            },
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [
                rootMigrationStep(RecordingRootMigrator(recorder: recorder))
            ],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            ),
            protectedDataAvailabilityMonitor: monitor
        )
        interactor.presenter = output

        interactor.setup(runMigrations: true)
        wait(
            for: [protectedDataObserverRegistered],
            timeout: Constants.defaultExpectationDuration
        )

        // Repeated taps while locked remain attached to this same attempt.
        interactor.setup(runMigrations: true)
        interactor.setup(runMigrations: false)
        XCTAssertTrue(recorder.snapshot.isEmpty)

        monitor.makeAvailable()
        wait(
            for: [completionExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(
            recorder.snapshot,
            [
                .migration,
                .storagePreflightProvider,
                .storagePreflight,
                .chainRegistry,
                .walletSettingsProvider,
                .walletSetup,
                .coldBoot
            ]
        )
        verify(output, times(0)).didFailSetup(any())
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
    }

    func testSynchronouslyBlockedPreflightDoesNotRetainInteractorAfterDeinit() {
        let blockedRequestStarted = expectation(
            description: "blocking preflight starts"
        )
        let lateCallbacksDelivered = expectation(
            description: "blocking preflight returns after owner deinit"
        )
        let blockedPreflight = SynchronouslyBlockingRootStoragePreflight(
            requestStartedExpectation: blockedRequestStarted,
            lateCallbacksDeliveredExpectation: lateCallbacksDelivered
        )
        defer {
            blockedPreflight.release()
        }

        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: RootSetupEventRecorder(),
            result: .success(nil)
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()

        stub(chainRegistry) { stub in
            stub.performHotBoot().thenDoNothing()
            stub.performColdBoot().thenDoNothing()
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didFailSetup(any()).then { _ in
                XCTFail("A deallocated interactor must not report failure")
            }
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                XCTFail("A deallocated interactor must not report success")
            }
        }

        var interactor: RootInteractor? = RootInteractor(
            chainRegistryProvider: { chainRegistry },
            storagePreflightProvider: { blockedPreflight },
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            )
        )
        weak var weakInteractor = interactor
        interactor?.presenter = output

        interactor?.setup(runMigrations: false)
        wait(
            for: [blockedRequestStarted],
            timeout: Constants.defaultExpectationDuration
        )

        interactor = nil
        let interactorReleased = expectation(
            description: "blocked invocation does not own RootInteractor"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakInteractor)
            interactorReleased.fulfill()
        }
        wait(
            for: [interactorReleased],
            timeout: Constants.defaultExpectationDuration
        )

        blockedPreflight.release()
        wait(
            for: [lateCallbacksDelivered],
            timeout: Constants.defaultExpectationDuration
        )

        let mainQueueDrained = expectation(
            description: "late callbacks cannot enqueue UI work"
        )
        DispatchQueue.main.async {
            mainQueueDrained.fulfill()
        }
        wait(
            for: [mainQueueDrained],
            timeout: Constants.defaultExpectationDuration
        )

        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()
        verify(output, times(0)).didFailSetup(any())
        verify(output, times(0)).didUpdateSetup(equal(to: .ready))
    }

    func testLowStorageFailureReportsRequiredBytesBeforeOpeningAnyStore() {
        let recorder = RootSetupEventRecorder()
        let requiredByteCount: UInt64 = 5_242_880
        let migrator = RecordingRootMigrator(
            recorder: recorder,
            error: CrashConsistentStoreReplacementError
                .insufficientStorageCapacity(
                    requiredByteCount: requiredByteCount,
                    availableByteCount: 1024
                )
        )
        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: recorder,
            result: .success(nil)
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()
        let failureExpectation = expectation(
            description: "typed low-storage failure is reported"
        )
        var failedState: RootSetupFailure?

        stub(output) { stub in
            stub.didUpdateSetup(any()).then { state in
                if case let .failed(failure) = state {
                    failedState = failure
                }
            }
            stub.didFailSetup(any()).then { failure in
                XCTAssertEqual(failedState, failure)
                XCTAssertEqual(failure.phase, .userStorageMigration)
                XCTAssertEqual(failure.incidentCode, .insufficientStorage)
                XCTAssertEqual(
                    failure.incidentCode.rawValue,
                    "INSUFFICIENT_STORAGE"
                )
                XCTAssertEqual(
                    failure.recoveryAction,
                    .freeStorage(requiredByteCount: requiredByteCount)
                )
                failureExpectation.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: {
                XCTFail("Low-space migration failure must not resolve registry")
                return chainRegistry
            },
            storagePreflightProvider: {
                XCTFail("Low-space migration failure must not open storage")
                return ImmediateRootStoragePreflight(result: .success(()))
            },
            settingsProvider: {
                XCTFail("Low-space migration failure must not resolve settings")
                return settings
            },
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [rootMigrationStep(migrator)],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            ),
            protectedDataAvailabilityMonitor:
            ControllableRootProtectedDataAvailabilityMonitor(
                isAvailable: true
            )
        )
        interactor.presenter = output

        interactor.setup(runMigrations: true)
        wait(
            for: [failureExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(recorder.snapshot, [.migration])
        verify(output, times(1)).didFailSetup(any())
        verify(output, times(0)).didUpdateSetup(equal(to: .ready))
    }

    func testTypedSetupErrorsMapDeterministicallyToStableIncidentCodes() {
        let scenarios = [
            RootFailureMappingScenario(
                phase: .languageMigration,
                error: RootSetupTestError.migrationFailed,
                incidentCode: .languageMigrationFailed,
                stableCode: "LANGUAGE_MIGRATION_FAILED",
                recoveryAction: .retry
            ),
            RootFailureMappingScenario(
                phase: .userStorageMigration,
                error: UserStorageMigrationError.modelUnavailable(.version13),
                incidentCode: .userStorageCompatibilityMissing,
                stableCode: "USER_STORAGE_COMPATIBILITY_MISSING",
                recoveryAction: .installLatestBuild
            ),
            RootFailureMappingScenario(
                phase: .userStorageMigration,
                error: UserStorageMigrationError.stagedStoreValidationFailed,
                incidentCode: .userStorageIntegrityRejected,
                stableCode: "USER_STORAGE_INTEGRITY_REJECTED",
                recoveryAction: .installLatestBuild
            ),
            RootFailureMappingScenario(
                phase: .userStorageMigration,
                error: RootSetupTestError.migrationFailed,
                incidentCode: .userStorageMigrationFailed,
                stableCode: "USER_STORAGE_MIGRATION_FAILED",
                recoveryAction: .retry
            ),
            RootFailureMappingScenario(
                phase: .substrateMigration,
                error: SubstrateStorageMigrationError.mappingUnavailable(
                    .version7,
                    .version8,
                    RootSetupTestError.migrationFailed
                ),
                incidentCode: .substrateCompatibilityMissing,
                stableCode: "SUBSTRATE_COMPATIBILITY_MISSING",
                recoveryAction: .installLatestBuild
            ),
            RootFailureMappingScenario(
                phase: .substrateMigration,
                error: SubstrateStorageMigrationError
                    .stagedStoreRowCountMismatch("sanitized", 1, 0),
                incidentCode: .substrateIntegrityRejected,
                stableCode: "SUBSTRATE_INTEGRITY_REJECTED",
                recoveryAction: .installLatestBuild
            ),
            RootFailureMappingScenario(
                phase: .substrateMigration,
                error: RootSetupTestError.migrationFailed,
                incidentCode: .substrateMigrationFailed,
                stableCode: "SUBSTRATE_MIGRATION_FAILED",
                recoveryAction: .retry
            ),
            RootFailureMappingScenario(
                phase: .substratePreflight,
                error: RootStoragePreflightError.managedObjectClassUnavailable(
                    entityName: "SanitizedEntity",
                    className: "SanitizedClass"
                ),
                incidentCode: .substratePreflightCompatibilityMissing,
                stableCode: "SUBSTRATE_PREFLIGHT_COMPATIBILITY_MISSING",
                recoveryAction: .installLatestBuild
            ),
            RootFailureMappingScenario(
                phase: .substratePreflight,
                error: RootSetupTestError.substrateStorageOpenFailed,
                incidentCode: .substratePreflightFailed,
                stableCode: "SUBSTRATE_PREFLIGHT_FAILED",
                recoveryAction: .retry
            ),
            RootFailureMappingScenario(
                phase: .selectedWalletOpening,
                error: SelectedWalletSettingsError.duplicateWalletIdentifier,
                incidentCode: .walletMappingConflict,
                stableCode: "WALLET_MAPPING_CONFLICT",
                recoveryAction: .installLatestBuild
            ),
            RootFailureMappingScenario(
                phase: .selectedWalletOpening,
                error: MetaAccountMapperError.invalidWalletRecord,
                incidentCode: .walletRecordRejected,
                stableCode: "WALLET_RECORD_REJECTED",
                recoveryAction: .installLatestBuild
            ),
            RootFailureMappingScenario(
                phase: .selectedWalletOpening,
                error: RootSetupTestError.walletRepositoryFailed,
                incidentCode: .selectedWalletOpeningFailed,
                stableCode: "SELECTED_WALLET_OPENING_FAILED",
                recoveryAction: .retry
            )
        ]

        for scenario in scenarios {
            assertRootFailureMapping(scenario)
        }
    }

    func testWalletOpeningCompletingAfterFifteenSecondsAutoContinuesWithoutRetry() {
        let requestStarted = expectation(description: "wallet opening starts")
        let slowExpectation = expectation(description: "wallet opening reports slow")
        let setupCompleted = expectation(description: "late wallet result completes setup")
        let settings = ControllableRootSelectedWalletSettings(
            requestStartedExpectations: [requestStarted]
        )
        let deadlineScheduler = ManualRootSetupDeadlineScheduler()
        let clock = ControllableRootMonotonicClock(now: 200)
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()

        stub(chainRegistry) { stub in
            stub.performColdBoot().thenDoNothing()
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didUpdateSetup(
                equal(to: .slow(.selectedWalletOpening, elapsedTime: 15))
            ).then { _ in
                slowExpectation.fulfill()
            }
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                setupCompleted.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: { chainRegistry },
            storagePreflightProvider: {
                ImmediateRootStoragePreflight(result: .success(()))
            },
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            ),
            setupDeadline: 15,
            setupDeadlineScheduler: deadlineScheduler.schedule,
            monotonicTimeProvider: clock.currentTime
        )
        interactor.presenter = output

        interactor.setup(runMigrations: false)
        wait(
            for: [requestStarted],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(deadlineScheduler.delays, [15, 15])

        clock.advance(by: 15)
        deadlineScheduler.fire(at: 1)
        wait(for: [slowExpectation], timeout: Constants.defaultExpectationDuration)

        interactor.setup(runMigrations: false)
        interactor.setup(runMigrations: true)
        XCTAssertEqual(settings.requestCount, 1)

        settings.resolveRequest(at: 0, with: .success(nil))
        wait(
            for: [setupCompleted],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(settings.requestCount, 1)
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(1)).performColdBoot()
        verify(output, times(0)).didFailSetup(any())
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
    }

    func testSubstratePreflightFailureCanRetryWithoutRemigrationOrPrematureBoot() {
        let recorder = RootSetupEventRecorder()
        let storageFacade = RecordingUserDataStorageTestFacade(recorder: recorder)
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        let saveExpectation = expectation(description: "selected wallet is saved")
        settings.save(
            value: AccountGenerator.generateMetaAccount(),
            runningCompletionIn: .main
        ) { result in
            if case let .failure(error) = result {
                XCTFail("Unexpected wallet save error: \(error)")
            }
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)
        recorder.reset()

        let preflight = SequencedRootStoragePreflight(
            recorder: recorder,
            results: [
                .failure(RootSetupTestError.substrateStorageOpenFailed),
                .success(())
            ]
        )
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()
        let failureExpectation = expectation(description: "first preflight fails")
        let completionExpectation = expectation(description: "retry completes")

        stub(chainRegistry) { stub in
            stub.performHotBoot().then {
                recorder.record(.hotBoot)
            }
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didFailSetup(any()).then { _ in
                failureExpectation.fulfill()
            }
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                completionExpectation.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: { preflight },
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [
                rootMigrationStep(RecordingRootMigrator(recorder: recorder))
            ],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            )
        )
        interactor.presenter = output

        interactor.setup(runMigrations: true)
        wait(for: [failureExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(recorder.snapshot, [.migration, .storagePreflight])
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()

        interactor.setup(runMigrations: true)
        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(
            recorder.snapshot,
            [
                .migration,
                .storagePreflight,
                .storagePreflight,
                .chainRegistry,
                .walletRepository,
                .hotBoot
            ]
        )
        verify(chainRegistry, times(1)).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()
        verify(output, times(1)).didFailSetup(any())
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
    }

    func testAdversarialPreflightMultipleCallbacksCanOnlyOpenWalletAndBootOnce() {
        let recorder = RootSetupEventRecorder()
        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: recorder,
            result: .success(nil)
        )
        let preflight = AdversarialRootStoragePreflight(recorder: recorder)
        let chainRegistry = MockChainRegistryProtocol()
        let output = MockRootInteractorOutputProtocol()
        let completionExpectation = expectation(description: "setup completes once")
        completionExpectation.assertForOverFulfill = true
        let failureExpectation = expectation(description: "late failure is ignored")
        failureExpectation.isInverted = true

        stub(chainRegistry) { stub in
            stub.performColdBoot().then {
                recorder.record(.coldBoot)
            }
        }
        stub(output) { stub in
            stub.didUpdateSetup(any()).thenDoNothing()
            stub.didUpdateSetup(equal(to: .ready)).then { _ in
                completionExpectation.fulfill()
            }
            stub.didFailSetup(any()).then { _ in
                failureExpectation.fulfill()
            }
        }

        let interactor = RootInteractor(
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: { preflight },
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: [],
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            )
        )
        interactor.presenter = output

        interactor.setup(runMigrations: false)

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
        wait(for: [failureExpectation], timeout: 0.2)

        XCTAssertEqual(
            recorder.snapshot,
            [.storagePreflight, .chainRegistry, .walletSetup, .coldBoot]
        )
        verify(chainRegistry, times(0)).performHotBoot()
        verify(chainRegistry, times(1)).performColdBoot()
        verify(output, times(1)).didUpdateSetup(equal(to: .ready))
        verify(output, times(0)).didFailSetup(any())
    }

    func testOnlyTonWalletAllowsLoginWithoutPincodeButFailsClosedAndPreservesRowWithPincode() throws {
        let storageFacade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        try insertTonOnlyWallet(in: storageFacade)
        let before = try tonOnlyWalletSnapshot(in: storageFacade)
        let setupExpectation = expectation(description: "unsupported wallet store is classified")

        settings.setup(runningCompletionIn: .main) { result in
            do {
                XCTAssertNil(try result.get())
            } catch {
                XCTFail("Unsupported wallet rows must be a controlled state: \(error)")
            }
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        let loginHelper = StartViewHelper(
            keystore: InMemoryKeychain(),
            selectedWalletSettings: settings,
            userDefaultsStorage: InMemorySettingsManager()
        )
        guard case .login = loginHelper.startView(onboardingConfig: nil) else {
            return XCTFail("A user without a PIN must be allowed to add a supported wallet")
        }

        let keystore = InMemoryKeychain()
        try keystore.saveKey(
            Data("123456".utf8),
            with: KeystoreTag.pincode.rawValue
        )
        let chainRegistry = MockChainRegistryProtocol()
        let wireframe = MockRootWireframeProtocol()
        let view = AlertCapturingViewController()
        let brokenExpectation = expectation(description: "unsupported wallet routes to broken")
        let alertExpectation = expectation(description: "unsupported wallet explanation is visible")

        stub(chainRegistry) { stub in
            stub.performColdBoot().thenDoNothing()
        }
        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).thenDoNothing()
            stub.showBroken(on: any()).then { _ in
                brokenExpectation.fulfill()
            }
        }
        view.onPresent = { presentedController in
            guard let alert = presentedController as? UIAlertController else {
                return XCTFail("Expected a retryable unsupported-wallet alert")
            }

            XCTAssertTrue(alert.message?.contains("selected wallet") == true)
            XCTAssertTrue(alert.message?.contains("wallet data was not changed") == true)
            XCTAssertTrue(alert.message?.contains("WALLET_RECORD_REJECTED") == true)
            alertExpectation.fulfill()
        }

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: InMemorySettingsManager(),
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            view: view,
            chainRegistryProvider: { chainRegistry }
        )

        presenter.loadOnLaunch()

        wait(
            for: [brokenExpectation, alertExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertEqual(settings.storeState, .unsupportedOnly)
        XCTAssertTrue(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
        XCTAssertEqual(try tonOnlyWalletSnapshot(in: storageFacade), before)
        verify(chainRegistry).performColdBoot()
        verify(chainRegistry, times(0)).performHotBoot()
        verify(wireframe, times(0)).showLocalAuthentication(on: any())
        verify(wireframe, times(0)).showPincodeSetup(on: any())
        verify(wireframe, times(0)).showMain(on: any())
        verify(wireframe, times(0)).showOnboarding(on: any(), with: any())
    }

    func testMigrationThenRealSubstrateOpenThenWalletOpenThenBootRoutesSelectedWalletToPin() throws {
        // given

        let recorder = RootSetupEventRecorder()
        let storageFacade = RecordingUserDataStorageTestFacade(recorder: recorder)
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        let selectedAccount = AccountGenerator.generateMetaAccount()
        let saveExpectation = XCTestExpectation(description: "selected account is saved")

        settings.save(value: selectedAccount, runningCompletionIn: .main) { result in
            if case let .failure(error) = result {
                XCTFail("Unexpected save error: \(error)")
            }
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)
        recorder.reset()

        let keystore = InMemoryKeychain()
        try keystore.saveKey(
            Data("123456".utf8),
            with: KeystoreTag.pincode.rawValue
        )

        let migrator = RecordingRootMigrator(recorder: recorder)
        let substrateModelURL = try XCTUnwrap(
            Bundle(for: SubstrateDataStorageFacade.self).url(
                forResource: "SubstrateDataModel",
                withExtension: "momd"
            )
        )
        let substrateService = CoreDataService(
            configuration: CoreDataServiceConfiguration(
                modelURL: substrateModelURL,
                storageType: .inMemory
            )
        )
        let recordingSubstrateService = RecordingCoreDataService(
            service: substrateService,
            recorder: recorder
        )
        let storagePreflight = RootCoreDataStoragePreflight(
            databaseService: recordingSubstrateService
        )
        defer {
            try? substrateService.close()
        }

        let chainRegistry = MockChainRegistryProtocol()
        let wireframe = MockRootWireframeProtocol()
        let readinessReporter = RecordingRootStartupReadinessReporter()
        let pinExpectation = XCTestExpectation(description: "selected wallet routes to pin")
        let onboardingService = StubOnboardingService(
            result: .failure(OnboardingServiceError.empty)
        )

        stub(chainRegistry) { stub in
            stub.performHotBoot().then {
                recorder.record(.hotBoot)
            }
        }
        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).thenDoNothing()
            stub.showLocalAuthentication(on: any()).then { _ in
                pinExpectation.fulfill()
            }
        }

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: InMemorySettingsManager(),
            migrationSteps: [rootMigrationStep(migrator)],
            onboardingService: onboardingService,
            chainRegistryProvider: {
                recorder.record(.chainRegistry)
                return chainRegistry
            },
            storagePreflightProvider: {
                storagePreflight
            },
            startupReadinessReporter: readinessReporter
        )

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [pinExpectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(
            recorder.snapshot,
            [
                .migration,
                .storagePreflight,
                .chainRegistry,
                .walletRepository,
                .hotBoot
            ]
        )
        XCTAssertEqual(onboardingService.fetchCallCount, 1)
        XCTAssertEqual(readinessReporter.readyCount, 1)
        XCTAssertEqual(readinessReporter.failureCount, 0)
        verify(chainRegistry, times(1)).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()
    }

    func testPresenterSlowStateShowsNonterminalGuidanceAndStructuredPhase() {
        let wireframe = MockRootWireframeProtocol()
        let view = AlertCapturingViewController()
        let readinessReporter = RecordingRootStartupReadinessReporter()
        let presenter = createPresenter(
            wireframe: wireframe,
            settings: SelectedWalletSettings(
                storageFacade: UserDataStorageTestFacade(),
                operationQueue: OperationQueue()
            ),
            keystore: InMemoryKeychain(),
            userDefaultsStorage: InMemorySettingsManager(),
            view: view,
            startupReadinessReporter: readinessReporter
        )

        presenter.didUpdateSetup(.slow(.substratePreflight, elapsedTime: 15))

        guard case let .updating(message)? = view.receivedStates.last else {
            return XCTFail("Expected nonterminal startup guidance")
        }
        XCTAssertEqual(message, "Updating/opening your wallet—keep Fearless open.")
        XCTAssertEqual(
            readinessReporter.slowEvents,
            [RootSetupSlowEvent(phase: .substratePreflight, elapsedTime: 15)]
        )
        XCTAssertEqual(readinessReporter.failureCount, 0)
    }

    func testPresenterTypedFailureShowsPhaseGuidanceAndIncidentCode() {
        let wireframe = MockRootWireframeProtocol()
        let view = AlertCapturingViewController()
        let readinessReporter = RecordingRootStartupReadinessReporter()
        let failure = RootSetupFailure(
            phase: .userStorageMigration,
            incidentCode: .insufficientStorage,
            elapsedTime: 4,
            recoveryAction: .freeStorage(requiredByteCount: 1_048_576)
        )
        let alertExpectation = expectation(description: "typed setup alert")

        view.onPresent = { presentedController in
            guard let alert = presentedController as? UIAlertController else {
                return XCTFail("Expected a setup failure alert")
            }

            XCTAssertTrue(alert.message?.contains("wallet storage safely") == true)
            XCTAssertTrue(alert.message?.contains("INSUFFICIENT_STORAGE") == true)
            XCTAssertTrue(alert.message?.contains("1 MB") == true)
            alertExpectation.fulfill()
        }

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: SelectedWalletSettings(
                storageFacade: UserDataStorageTestFacade(),
                operationQueue: OperationQueue()
            ),
            keystore: InMemoryKeychain(),
            userDefaultsStorage: InMemorySettingsManager(),
            view: view,
            startupReadinessReporter: readinessReporter
        )

        presenter.didFailSetup(failure)

        wait(for: [alertExpectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(readinessReporter.failures, [failure])
    }

    func testReadinessReporterEmitsReadyMarkerExactlyOnce() {
        let lock = NSLock()
        var markerCount = 0
        let reporter = RootStartupReadinessReporter { _ in
            lock.lock()
            markerCount += 1
            lock.unlock()
        }

        reporter.reportReady()
        reporter.reportReady()

        lock.lock()
        let result = markerCount
        lock.unlock()
        XCTAssertEqual(result, 1)
    }

    func testLateOnboardingResultAfterTimeoutCannotReplaceLogin() {
        // given

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        let wireframe = MockRootWireframeProtocol()
        let chainRegistry = MockChainRegistryProtocol()
        let requestStartedExpectation = XCTestExpectation(
            description: "onboarding request starts"
        )
        let loginExpectation = XCTestExpectation(
            description: "timeout falls back to login"
        )
        let lateResultExpectation = XCTestExpectation(
            description: "late onboarding result is ignored"
        )
        lateResultExpectation.isInverted = true
        let onboardingService = LateCompletingOnboardingService(
            startedExpectation: requestStartedExpectation
        )
        var loginRouteCount = 0

        stub(chainRegistry) { stub in
            stub.performColdBoot().thenDoNothing()
        }
        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).thenDoNothing()
            stub.showMain(on: any()).then { _ in
                loginRouteCount += 1
                if loginRouteCount == 1 {
                    loginExpectation.fulfill()
                } else {
                    lateResultExpectation.fulfill()
                }
            }
            stub.showOnboarding(on: any(), with: any()).then { _ in
                lateResultExpectation.fulfill()
            }
        }

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: InMemoryKeychain(),
            userDefaultsStorage: InMemorySettingsManager(),
            onboardingService: onboardingService,
            onboardingConfigTimeoutNanoseconds: 50_000_000,
            chainRegistryProvider: { chainRegistry }
        )

        // when

        presenter.loadOnLaunch()

        // then

        wait(
            for: [requestStartedExpectation, loginExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        onboardingService.succeed(with: Self.makeOnboardingPlatform())
        wait(for: [lateResultExpectation], timeout: 0.2)

        XCTAssertEqual(loginRouteCount, 1)
        verify(wireframe, times(0)).showOnboarding(on: any(), with: any())
    }

    func testProtectedDataFailureIsVisibleAndNeverBypassesAuthentication() {
        // given

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        let selectedAccount = AccountGenerator.generateMetaAccount()
        let saveExpectation = XCTestExpectation(description: "selected account is saved")

        settings.save(value: selectedAccount, runningCompletionIn: .main) { result in
            if case let .failure(error) = result {
                XCTFail("Unexpected save error: \(error)")
            }
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)

        let keystore = MockKeystoreProtocol()
        let chainRegistry = MockChainRegistryProtocol()
        let wireframe = MockRootWireframeProtocol()
        let alertController = AlertCapturingViewController()
        let brokenExpectation = XCTestExpectation(description: "broken route is selected")
        let alertExpectation = XCTestExpectation(description: "protected data error is visible")
        let onboardingService = StubOnboardingService(
            result: .failure(OnboardingServiceError.empty)
        )

        stub(keystore) { stub in
            stub.checkKey(for: any()).thenThrow(RootSetupTestError.protectedDataUnavailable)
        }
        stub(chainRegistry) { stub in
            stub.performHotBoot().thenDoNothing()
        }
        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).thenDoNothing()
            stub.showBroken(on: any()).then { _ in
                brokenExpectation.fulfill()
            }
        }
        alertController.onPresent = { presentedController in
            guard let alert = presentedController as? UIAlertController else {
                XCTFail("Expected a retryable protected-data alert")
                return
            }

            XCTAssertEqual(alert.actions.count, 1)
            XCTAssertFalse(alert.message?.isEmpty ?? true)
            alertExpectation.fulfill()
        }

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: InMemorySettingsManager(),
            onboardingService: onboardingService,
            view: alertController,
            chainRegistryProvider: { chainRegistry }
        )

        // when

        presenter.loadOnLaunch()

        // then

        wait(
            for: [brokenExpectation, alertExpectation],
            timeout: Constants.defaultExpectationDuration
        )
        XCTAssertEqual(onboardingService.fetchCallCount, 1)
        verify(wireframe, times(0)).showLocalAuthentication(on: any())
        verify(wireframe, times(0)).showPincodeSetup(on: any())
        verify(wireframe, times(0)).showMain(on: any())
        verify(wireframe, times(0)).showOnboarding(on: any(), with: any())
    }

    func testUnselectedWalletIsRecoveredWithoutDeletingPincodeOrBypassingAuthentication() throws {
        let operationQueue = OperationQueue()
        let storageFacade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let repository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(ManagedMetaAccountMapper())
        )
        let seedOperation = repository.saveOperation({
            [
                ManagedMetaAccountModel(
                    info: wallet,
                    isSelected: false,
                    order: 1
                )
            ]
        }, {
            []
        })
        operationQueue.addOperations([seedOperation], waitUntilFinished: true)
        _ = try XCTUnwrap(seedOperation.result).get()

        let keystore = InMemoryKeychain()
        try keystore.saveKey(
            Data("123456".utf8),
            with: KeystoreTag.pincode.rawValue
        )
        let chainRegistry = MockChainRegistryProtocol()
        let wireframe = MockRootWireframeProtocol()
        let authenticationExpectation = expectation(
            description: "recovered wallet still requires authentication"
        )

        stub(chainRegistry) { stub in
            stub.performHotBoot().thenDoNothing()
        }
        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).thenDoNothing()
            stub.showLocalAuthentication(on: any()).then { _ in
                authenticationExpectation.fulfill()
            }
        }

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: InMemorySettingsManager(),
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            chainRegistryProvider: { chainRegistry }
        )

        presenter.loadOnLaunch()

        wait(
            for: [authenticationExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertTrue(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
        XCTAssertEqual(settings.value, wallet)
        verify(chainRegistry).performHotBoot()
        verify(chainRegistry, times(0)).performColdBoot()
        verify(wireframe, times(0)).showMain(on: any())
        verify(wireframe, times(0)).showPincodeSetup(on: any())
    }

    func testConfirmedEmptyWalletStoreReturnsLoginAndDeletesPincode() throws {
        // given

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        let setupExpectation = expectation(description: "empty wallet store is confirmed")
        settings.setup(runningCompletionIn: .main) { result in
            do {
                XCTAssertNil(try result.get())
            } catch {
                XCTFail("Unexpected empty-store setup error: \(error)")
            }
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        let keystore = InMemoryKeychain()
        try keystore.saveKey(
            Data("123456".utf8),
            with: KeystoreTag.pincode.rawValue
        )
        let helper = StartViewHelper(
            keystore: keystore,
            selectedWalletSettings: settings,
            userDefaultsStorage: InMemorySettingsManager()
        )

        // when

        let startView = helper.startView(onboardingConfig: nil)

        // then

        guard case .login = startView else {
            XCTFail("Expected login for an empty wallet store")
            return
        }

        XCTAssertFalse(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
    }

    func testConfirmedEmptyWalletStoreFailsClosedWhenPincodeDeletionFails() {
        // given

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        let setupExpectation = expectation(description: "empty wallet store is confirmed")
        settings.setup(runningCompletionIn: .main) { result in
            do {
                XCTAssertNil(try result.get())
            } catch {
                XCTFail("Unexpected empty-store setup error: \(error)")
            }
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        let keystore = MockKeystoreProtocol()
        let helper = StartViewHelper(
            keystore: keystore,
            selectedWalletSettings: settings,
            userDefaultsStorage: InMemorySettingsManager()
        )

        stub(keystore) { stub in
            stub.checkKey(for: any()).thenReturn(true)
            stub.deleteKey(for: any()).thenThrow(RootSetupTestError.protectedDataUnavailable)
        }

        // when

        let startView = helper.startView(onboardingConfig: nil)

        // then

        guard case .broken = startView else {
            XCTFail("Expected protected-data failure when the stale PIN cannot be removed")
            return
        }

        verify(keystore).deleteKey(for: KeystoreTag.pincode.rawValue)
    }

    func testOnboardingDecision() throws {
        // given

        let wireframe = MockRootWireframeProtocol()

        let keystore = InMemoryKeychain()

        let expectedPincode = "123456"
        try keystore.saveKey(
            expectedPincode.data(using: .utf8)!,
            with: KeystoreTag.pincode.rawValue
        )

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        let userDefaultsStorage = InMemorySettingsManager()

        let onboardingService = StubOnboardingService(
            result: .success(Self.makeOnboardingPlatform())
        )

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: userDefaultsStorage,
            onboardingService: onboardingService
        )

        let splashExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).then { _ in
                splashExpectation.fulfill()
            }
        }

        let onboardingExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showOnboarding(on: any(), with: any()).then { _ in
                onboardingExpectation.fulfill()
            }
        }

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [splashExpectation, onboardingExpectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertTrue(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
    }

    func testPincodeSetupDecision() {
        // given

        let wireframe = MockRootWireframeProtocol()

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let selectedAccount = AccountGenerator.generateMetaAccount()
        let saveExpectation = XCTestExpectation()
        settings.save(value: selectedAccount, runningCompletionIn: .main) { result in
            if case let .failure(error) = result {
                XCTFail("Unexpected save error: \(error)")
            }
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)

        let keystore = InMemoryKeychain()
        let userDefaultsStorage = InMemorySettingsManager()

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: userDefaultsStorage
        )

        let splashExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).then { _ in
                splashExpectation.fulfill()
            }
        }

        let pincodeExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showPincodeSetup(on: any()).then { _ in
                pincodeExpectation.fulfill()
            }
            stub.showMain(on: any()).thenDoNothing()
        }

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [splashExpectation, pincodeExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testMainScreenDecision() throws {
        // given

        let wireframe = MockRootWireframeProtocol()

        let keystore = InMemoryKeychain()

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let selectedAccount = AccountGenerator.generateMetaAccount()
        let saveExpectation = XCTestExpectation()
        settings.save(value: selectedAccount, runningCompletionIn: .main) { result in
            if case let .failure(error) = result {
                XCTFail("Unexpected save error: \(error)")
            }
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)

        let expectedPincode = "123456"
        try keystore.saveKey(
            expectedPincode.data(using: .utf8)!,
            with: KeystoreTag.pincode.rawValue
        )
        let userDefaultsStorage = InMemorySettingsManager()

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: userDefaultsStorage
        )

        let splashExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).then { _ in
                splashExpectation.fulfill()
            }
        }

        let mainScreenExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showLocalAuthentication(on: any()).then { _ in
                mainScreenExpectation.fulfill()
            }
            stub.showMain(on: any()).thenDoNothing()
        }

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [splashExpectation, mainScreenExpectation], timeout: Constants.defaultExpectationDuration)
    }

    private func createPresenter(
        wireframe: MockRootWireframeProtocol,
        settings: SelectedWalletSettings,
        keystore: KeystoreProtocol,
        userDefaultsStorage: SettingsManagerProtocol,
        migrationSteps: [RootSetupMigrationStep] = [],
        onboardingService: OnboardingServiceProtocol = StubOnboardingService(result: .failure(OnboardingServiceError.empty)),
        onboardingConfigTimeoutNanoseconds: UInt64 = 5_000_000_000,
        view: ControllerBackedProtocol? = nil,
        chainRegistryProvider: @escaping () -> ChainRegistryProtocol = {
            ChainRegistryFacade.sharedRegistry
        },
        storagePreflightProvider: @escaping RootStoragePreflightProvider = {
            ImmediateRootStoragePreflight(result: .success(()))
        },
        startupReadinessReporter: RootStartupReadinessReporting =
            RootStartupReadinessReporter.shared
    ) -> RootPresenter {
        let resolver = OnboardingConfigVersionResolver(userDefaultsStorage: userDefaultsStorage)

        let interactor = RootInteractor(
            chainRegistryProvider: chainRegistryProvider,
            storagePreflightProvider: storagePreflightProvider,
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: migrationSteps,
            onboardingService: onboardingService,
            onboardingConfigResolver: resolver
        )

        let startViewHelper = StartViewHelper(
            keystore: keystore,
            selectedWalletSettings: settings,
            userDefaultsStorage: userDefaultsStorage
        )
        let presenter = RootPresenter(
            localizationManager: LocalizationManager.shared,
            startViewHelper: startViewHelper,
            onboardingConfigTimeoutNanoseconds: onboardingConfigTimeoutNanoseconds,
            startupReadinessReporter: startupReadinessReporter
        )

        let presenterView = view ?? MockControllerBackedProtocol()

        presenter.view = presenterView
        presenter.window = UIWindow()
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        return presenter
    }

    private func assertRootFailureMapping(
        _ scenario: RootFailureMappingScenario
    ) {
        let output = MockRootInteractorOutputProtocol()
        let chainRegistry = MockChainRegistryProtocol()
        let recorder = RootSetupEventRecorder()
        let failureExpectation = expectation(
            description: "maps \(scenario.stableCode)"
        )
        var failedState: RootSetupFailure?

        stub(output) { stub in
            stub.didUpdateSetup(any()).then { state in
                if case let .failed(failure) = state {
                    failedState = failure
                }
            }
            stub.didFailSetup(any()).then { failure in
                XCTAssertEqual(failedState, failure)
                XCTAssertEqual(failure.phase, scenario.phase)
                XCTAssertEqual(failure.incidentCode, scenario.incidentCode)
                XCTAssertEqual(
                    failure.incidentCode.rawValue,
                    scenario.stableCode
                )
                XCTAssertEqual(
                    failure.recoveryAction,
                    scenario.recoveryAction
                )
                failureExpectation.fulfill()
            }
        }

        let migrationSteps: [RootSetupMigrationStep]
        let preflightResult: Result<Void, Error>
        let walletResult: Result<MetaAccountModel?, Error>

        switch scenario.phase {
        case .languageMigration,
             .userStorageMigration,
             .substrateMigration:
            migrationSteps = [
                rootMigrationStep(
                    RecordingRootMigrator(
                        recorder: recorder,
                        error: scenario.error
                    ),
                    phase: scenario.phase
                )
            ]
            preflightResult = .success(())
            walletResult = .success(nil)
        case .substratePreflight:
            migrationSteps = []
            preflightResult = .failure(scenario.error)
            walletResult = .success(nil)
        case .selectedWalletOpening:
            migrationSteps = []
            preflightResult = .success(())
            walletResult = .failure(scenario.error)
        }

        let settings = RecordingImmediateRootSelectedWalletSettings(
            recorder: recorder,
            result: walletResult
        )
        let interactor = RootInteractor(
            chainRegistryProvider: { chainRegistry },
            storagePreflightProvider: {
                ImmediateRootStoragePreflight(result: preflightResult)
            },
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrationSteps: migrationSteps,
            onboardingService: StubOnboardingService(
                result: .failure(OnboardingServiceError.empty)
            ),
            onboardingConfigResolver: OnboardingConfigVersionResolver(
                userDefaultsStorage: InMemorySettingsManager()
            )
        )
        interactor.presenter = output

        interactor.setup(runMigrations: true)

        wait(
            for: [failureExpectation],
            timeout: Constants.defaultExpectationDuration
        )
        verify(output, times(1)).didFailSetup(any())
        verify(output, times(0)).didUpdateSetup(equal(to: .ready))
    }

    private func makeSubstrateInMemoryConfiguration() throws
        -> CoreDataServiceConfiguration {
        let modelURL = try XCTUnwrap(
            Bundle(for: SubstrateDataStorageFacade.self).url(
                forResource: "SubstrateDataModel",
                withExtension: "momd"
            )
        )

        return CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .inMemory
        )
    }

    private func executeSQLiteUpdate(
        _ sql: String,
        at storeURL: URL
    ) throws -> Int {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            storeURL.path,
            &database,
            SQLITE_OPEN_READWRITE,
            nil
        )

        guard openResult == SQLITE_OK, let database else {
            defer {
                if let database {
                    sqlite3_close(database)
                }
            }

            let message = database
                .flatMap(sqlite3_errmsg)
                .map { String(cString: $0) } ?? "unknown SQLite open error"
            throw NSError(
                domain: "RootStoragePreflightTests.SQLite",
                code: Int(openResult),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        defer {
            sqlite3_close(database)
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let executionResult = sqlite3_exec(
            database,
            sql,
            nil,
            nil,
            &errorMessage
        )
        defer {
            sqlite3_free(errorMessage)
        }

        guard executionResult == SQLITE_OK else {
            let message = errorMessage
                .map { String(cString: $0) } ?? "unknown SQLite update error"
            throw NSError(
                domain: "RootStoragePreflightTests.SQLite",
                code: Int(executionResult),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        return Int(sqlite3_changes(database))
    }

    private func performStoragePreflight(
        _ preflight: RootStoragePreflighting
    ) throws -> Result<Void, Error> {
        let completionExpectation = expectation(
            description: "storage preflight completes"
        )
        var result: Result<Void, Error>?

        preflight.preflight {
            result = $0
            completionExpectation.fulfill()
        }

        wait(
            for: [completionExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        return try XCTUnwrap(result)
    }

    private func insertTonOnlyWallet(in facade: UserDataStorageTestFacade) throws {
        try performCoreData(in: facade) { context in
            let wallet = CDMetaAccount(context: context)
            wallet.metaId = "root-ton-only-wallet"
            wallet.name = "Preserved TON Wallet"
            wallet.isSelected = true
            wallet.order = 1
            wallet.canExportEthereumMnemonic = false
            wallet.hasBackup = false
            wallet.favouriteChainIds = NSArray()
            wallet.setValue(false, forKey: "zeroBalanceAssetsHidden")
            wallet.setValue(Data(repeating: 0x51, count: 36), forKey: "tonAddress")
            wallet.setValue(Data(repeating: 0x52, count: 32), forKey: "tonPublicKey")
            wallet.setValue("v5R1", forKey: "tonContractVersion")
            try context.save()
        }
    }

    private func tonOnlyWalletSnapshot(
        in facade: UserDataStorageTestFacade
    ) throws -> RootTonOnlyWalletSnapshot {
        try performCoreData(in: facade) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(format: "metaId == %@", "root-ton-only-wallet")
            let wallet = try XCTUnwrap(context.fetch(request).first)

            return RootTonOnlyWalletSnapshot(
                identifier: try XCTUnwrap(wallet.metaId),
                name: try XCTUnwrap(wallet.name),
                isSelected: wallet.isSelected,
                order: wallet.order,
                tonAddress: wallet.value(forKey: "tonAddress") as? Data,
                tonPublicKey: wallet.value(forKey: "tonPublicKey") as? Data,
                tonContractVersion: wallet.value(forKey: "tonContractVersion") as? String
            )
        }
    }

    private func performCoreData<T>(
        in facade: UserDataStorageTestFacade,
        _ body: @escaping (NSManagedObjectContext) throws -> T
    ) throws -> T {
        let operationExpectation = expectation(description: "Core Data operation completes")
        var operationResult: Result<T, Error>?

        facade.databaseService.performAsync { context, error in
            do {
                if let error {
                    throw error
                }
                operationResult = .success(try body(XCTUnwrap(context)))
            } catch {
                operationResult = .failure(error)
            }

            operationExpectation.fulfill()
        }

        wait(for: [operationExpectation], timeout: Constants.defaultExpectationDuration)
        return try XCTUnwrap(operationResult).get()
    }
}

private struct RootTonOnlyWalletSnapshot: Equatable {
    let identifier: String
    let name: String
    let isSelected: Bool
    let order: Int32
    let tonAddress: Data?
    let tonPublicKey: Data?
    let tonContractVersion: String?
}

private enum RootSetupTestError: Error {
    case migrationFailed
    case protectedDataUnavailable
    case staleWalletLoadFailed
    case substrateStorageOpenFailed
    case walletRepositoryFailed
}

private struct RootFailureMappingScenario {
    let phase: RootSetupPhase
    let error: Error
    let incidentCode: RootSetupIncidentCode
    let stableCode: String
    let recoveryAction: RootSetupRecoveryAction
}

private enum RootSetupEvent: Equatable {
    case migration
    case storagePreflightProvider
    case storagePreflight
    case chainRegistry
    case walletSettingsProvider
    case walletSetup
    case walletRepository
    case hotBoot
    case coldBoot
}

private func rootMigrationStep(
    _ migrator: Migrating,
    phase: RootSetupPhase = .userStorageMigration
) -> RootSetupMigrationStep {
    RootSetupMigrationStep(phase: phase, migrator: migrator)
}

private final class RootSetupEventRecorder {
    private let lock = NSLock()
    private var events: [RootSetupEvent] = []

    var snapshot: [RootSetupEvent] {
        lock.lock()
        defer { lock.unlock() }

        return events
    }

    func record(_ event: RootSetupEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func reset() {
        lock.lock()
        events.removeAll()
        lock.unlock()
    }
}

private enum RootGenerationEvent: Equatable {
    case hotBoot
    case coldBoot
    case completed
    case failed
}

private enum RootGenerationRouteState: Equatable {
    case unresolved
    case completed
    case failed
}

private final class RootGenerationEventRecorder {
    private let lock = NSLock()
    private var events: [RootGenerationEvent] = []
    private var state = RootGenerationRouteState.unresolved

    var snapshot: [RootGenerationEvent] {
        lock.lock()
        defer { lock.unlock() }

        return events
    }

    var routeState: RootGenerationRouteState {
        lock.lock()
        defer { lock.unlock() }

        return state
    }

    func record(_ event: RootGenerationEvent) {
        lock.lock()
        events.append(event)

        switch event {
        case .completed:
            state = .completed
        case .failed:
            state = .failed
        case .hotBoot, .coldBoot:
            break
        }

        lock.unlock()
    }
}

private final class ManualRootSetupDeadlineScheduler {
    private let lock = NSLock()
    private let scheduledExpectations: [XCTestExpectation]
    private var scheduledDelays: [TimeInterval] = []
    private var actions: [() -> Void] = []

    init(scheduledExpectations: [XCTestExpectation] = []) {
        self.scheduledExpectations = scheduledExpectations
    }

    var delays: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }

        return scheduledDelays
    }

    func schedule(
        after delay: TimeInterval,
        action: @escaping () -> Void
    ) {
        lock.lock()
        let scheduledIndex = actions.count
        scheduledDelays.append(delay)
        actions.append(action)
        lock.unlock()

        if scheduledExpectations.indices.contains(scheduledIndex) {
            scheduledExpectations[scheduledIndex].fulfill()
        }
    }

    func fire(at index: Int) {
        lock.lock()
        let action = actions[index]
        lock.unlock()

        action()
    }
}

private final class ControllableRootMonotonicClock {
    private let lock = NSLock()
    private var now: TimeInterval

    init(now: TimeInterval) {
        self.now = now
    }

    func currentTime() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }

        return now
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        now += interval
        lock.unlock()
    }
}

private final class ControllableRootProtectedDataAvailabilityMonitor:
    RootProtectedDataAvailabilityMonitoring {
    private let lock = NSLock()
    private let firstObservationExpectation: XCTestExpectation?
    private var isAvailable: Bool
    private var didReportFirstObservation = false
    private var actions: [UUID: () -> Void] = [:]

    init(
        isAvailable: Bool,
        firstObservationExpectation: XCTestExpectation? = nil
    ) {
        self.isAvailable = isAvailable
        self.firstObservationExpectation = firstObservationExpectation
    }

    var isProtectedDataAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }

        return isAvailable
    }

    func observeDidBecomeAvailable(
        _ action: @escaping () -> Void
    ) -> RootProtectedDataAvailabilityObservation {
        let identifier = UUID()

        lock.lock()
        actions[identifier] = action
        let shouldReportFirstObservation = !didReportFirstObservation
        didReportFirstObservation = true
        lock.unlock()

        if shouldReportFirstObservation {
            firstObservationExpectation?.fulfill()
        }

        return RootTestProtectedDataAvailabilityObservation { [weak self] in
            self?.removeAction(identifier: identifier)
        }
    }

    func makeAvailable() {
        lock.lock()
        isAvailable = true
        let pendingActions = Array(actions.values)
        lock.unlock()

        pendingActions.forEach { $0() }
    }

    private func removeAction(identifier: UUID) {
        lock.lock()
        actions[identifier] = nil
        lock.unlock()
    }
}

private final class RootTestProtectedDataAvailabilityObservation:
    RootProtectedDataAvailabilityObservation {
    private let lock = NSLock()
    private var invalidationAction: (() -> Void)?

    init(invalidationAction: @escaping () -> Void) {
        self.invalidationAction = invalidationAction
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        lock.lock()
        let action = invalidationAction
        invalidationAction = nil
        lock.unlock()

        action?()
    }
}

private final class ControllableRootSelectedWalletSettings: RootSelectedWalletSettingsProtocol {
    private struct Request {
        let queue: DispatchQueue?
        let completion: (Result<MetaAccountModel?, Error>) -> Void
    }

    private let lock = NSLock()
    private let requestStartedExpectations: [XCTestExpectation]
    private var requests: [Request] = []

    init(requestStartedExpectations: [XCTestExpectation]) {
        self.requestStartedExpectations = requestStartedExpectations
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return requests.count
    }

    func setup(
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<MetaAccountModel?, Error>) -> Void)?
    ) {
        guard let completionClosure else {
            return
        }

        lock.lock()
        let requestIndex = requests.count
        requests.append(
            Request(
                queue: queue,
                completion: completionClosure
            )
        )
        lock.unlock()

        if requestStartedExpectations.indices.contains(requestIndex) {
            requestStartedExpectations[requestIndex].fulfill()
        }
    }

    func resolveRequest(
        at index: Int,
        with result: Result<MetaAccountModel?, Error>,
        deliveryExpectation: XCTestExpectation? = nil
    ) {
        lock.lock()
        let request = requests[index]
        lock.unlock()

        let deliver = {
            request.completion(result)
            deliveryExpectation?.fulfill()
        }

        if let queue = request.queue {
            queue.async(execute: deliver)
        } else {
            deliver()
        }
    }
}

private final class RecordingImmediateRootSelectedWalletSettings:
    RootSelectedWalletSettingsProtocol {
    private let recorder: RootSetupEventRecorder
    private let result: Result<MetaAccountModel?, Error>

    init(
        recorder: RootSetupEventRecorder,
        result: Result<MetaAccountModel?, Error>
    ) {
        self.recorder = recorder
        self.result = result
    }

    func setup(
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<MetaAccountModel?, Error>) -> Void)?
    ) {
        recorder.record(.walletSetup)

        guard let completionClosure else {
            return
        }

        if let queue {
            queue.async {
                completionClosure(self.result)
            }
        } else {
            completionClosure(result)
        }
    }
}

private final class SequencedRootSelectedWalletSettings:
    RootSelectedWalletSettingsProtocol {
    private let lock = NSLock()
    private let recorder: RootSetupEventRecorder
    private var results: [Result<MetaAccountModel?, Error>]

    init(
        recorder: RootSetupEventRecorder,
        results: [Result<MetaAccountModel?, Error>]
    ) {
        self.recorder = recorder
        self.results = results
    }

    func setup(
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<MetaAccountModel?, Error>) -> Void)?
    ) {
        recorder.record(.walletSetup)

        guard let completionClosure else {
            return
        }

        lock.lock()
        let result = results.isEmpty
            ? Result<MetaAccountModel?, Error>.failure(
                RootSetupTestError.walletRepositoryFailed
            )
            : results.removeFirst()
        lock.unlock()

        if let queue {
            queue.async {
                completionClosure(result)
            }
        } else {
            completionClosure(result)
        }
    }
}

private final class RecordingRootMigrator: Migrating {
    private let recorder: RootSetupEventRecorder
    private let error: Error?

    init(recorder: RootSetupEventRecorder, error: Error? = nil) {
        self.recorder = recorder
        self.error = error
    }

    func migrate() throws {
        recorder.record(.migration)

        if let error {
            throw error
        }
    }
}

private final class BlockingRootMigrator: Migrating {
    private let condition = NSCondition()
    private let recorder: RootSetupEventRecorder
    private let startedExpectation: XCTestExpectation
    private var isReleased = false
    private var invocationCountStorage = 0
    private var activeInvocationCount = 0
    private var maximumConcurrentInvocationCountStorage = 0

    init(
        recorder: RootSetupEventRecorder,
        startedExpectation: XCTestExpectation
    ) {
        self.recorder = recorder
        self.startedExpectation = startedExpectation
    }

    var invocationCount: Int {
        condition.lock()
        defer { condition.unlock() }

        return invocationCountStorage
    }

    var maximumConcurrentInvocationCount: Int {
        condition.lock()
        defer { condition.unlock() }

        return maximumConcurrentInvocationCountStorage
    }

    func migrate() throws {
        condition.lock()
        invocationCountStorage += 1
        activeInvocationCount += 1
        maximumConcurrentInvocationCountStorage = max(
            maximumConcurrentInvocationCountStorage,
            activeInvocationCount
        )
        condition.unlock()

        recorder.record(.migration)
        startedExpectation.fulfill()

        condition.lock()
        while !isReleased {
            condition.wait()
        }
        activeInvocationCount -= 1
        condition.unlock()
    }

    func release() {
        condition.lock()
        isReleased = true
        condition.broadcast()
        condition.unlock()
    }
}

private final class SequencedRootMigrator: Migrating {
    private let lock = NSLock()
    private let recorder: RootSetupEventRecorder
    private var results: [Result<Void, Error>]

    init(
        recorder: RootSetupEventRecorder,
        results: [Result<Void, Error>]
    ) {
        self.recorder = recorder
        self.results = results
    }

    func migrate() throws {
        recorder.record(.migration)

        lock.lock()
        let result = results.isEmpty
            ? Result<Void, Error>.failure(RootSetupTestError.migrationFailed)
            : results.removeFirst()
        lock.unlock()

        try result.get()
    }
}

private final class ControllableRootStoragePreflight: RootStoragePreflighting {
    private let lock = NSLock()
    private let requestStartedExpectations: [XCTestExpectation]
    private var completions: [(Result<Void, Error>) -> Void] = []

    init(requestStartedExpectations: [XCTestExpectation]) {
        self.requestStartedExpectations = requestStartedExpectations
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return completions.count
    }

    func preflight(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lock.lock()
        let requestIndex = completions.count
        completions.append(completion)
        lock.unlock()

        if requestStartedExpectations.indices.contains(requestIndex) {
            requestStartedExpectations[requestIndex].fulfill()
        }
    }

    func resolveRequest(
        at index: Int,
        with result: Result<Void, Error>,
        deliveryExpectation: XCTestExpectation? = nil
    ) {
        lock.lock()
        let completion = completions[index]
        lock.unlock()

        DispatchQueue.global().async {
            completion(result)
            deliveryExpectation?.fulfill()
        }
    }
}

private final class SynchronouslyBlockingRootStoragePreflight:
    RootStoragePreflighting {
    private let releaseSemaphore = DispatchSemaphore(value: 0)
    private let releaseLock = NSLock()
    private let requestStartedExpectation: XCTestExpectation
    private let lateCallbacksDeliveredExpectation: XCTestExpectation
    private var isReleased = false

    init(
        requestStartedExpectation: XCTestExpectation,
        lateCallbacksDeliveredExpectation: XCTestExpectation
    ) {
        self.requestStartedExpectation = requestStartedExpectation
        self.lateCallbacksDeliveredExpectation =
            lateCallbacksDeliveredExpectation
    }

    func preflight(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        requestStartedExpectation.fulfill()
        releaseSemaphore.wait()

        completion(.success(()))
        completion(.failure(RootSetupTestError.substrateStorageOpenFailed))
        lateCallbacksDeliveredExpectation.fulfill()
    }

    func release() {
        releaseLock.lock()
        defer { releaseLock.unlock() }

        guard !isReleased else {
            return
        }

        isReleased = true
        releaseSemaphore.signal()
    }
}

private final class RootStoragePreflightSequence {
    private let lock = NSLock()
    private var preflights: [RootStoragePreflighting]
    private var invocationCountStorage = 0

    init(preflights: [RootStoragePreflighting]) {
        self.preflights = preflights
    }

    var invocationCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return invocationCountStorage
    }

    func next() -> RootStoragePreflighting {
        lock.lock()
        defer { lock.unlock() }

        invocationCountStorage += 1

        guard preflights.isNotEmpty else {
            return ImmediateRootStoragePreflight(
                result: .failure(
                    RootSetupTestError.substrateStorageOpenFailed
                )
            )
        }

        return preflights.removeFirst()
    }
}

private final class ImmediateRootStoragePreflight: RootStoragePreflighting {
    private let result: Result<Void, Error>

    init(result: Result<Void, Error>) {
        self.result = result
    }

    func preflight(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(result)
    }
}

private final class RecordingRootStoragePreflight: RootStoragePreflighting {
    private let recorder: RootSetupEventRecorder
    private let result: Result<Void, Error>

    init(
        recorder: RootSetupEventRecorder,
        result: Result<Void, Error>
    ) {
        self.recorder = recorder
        self.result = result
    }

    func preflight(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        recorder.record(.storagePreflight)
        completion(result)
    }
}

private final class AdversarialRootStoragePreflight: RootStoragePreflighting {
    private let recorder: RootSetupEventRecorder

    init(recorder: RootSetupEventRecorder) {
        self.recorder = recorder
    }

    func preflight(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        recorder.record(.storagePreflight)
        completion(.success(()))
        completion(.success(()))
        completion(.failure(RootSetupTestError.substrateStorageOpenFailed))
    }
}

private final class SequencedRootStoragePreflight: RootStoragePreflighting {
    private let lock = NSLock()
    private let recorder: RootSetupEventRecorder
    private var results: [Result<Void, Error>]

    init(
        recorder: RootSetupEventRecorder,
        results: [Result<Void, Error>]
    ) {
        self.recorder = recorder
        self.results = results
    }

    func preflight(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        recorder.record(.storagePreflight)

        lock.lock()
        let result = results.isEmpty
            ? Result<Void, Error>.failure(RootSetupTestError.substrateStorageOpenFailed)
            : results.removeFirst()
        lock.unlock()

        completion(result)
    }
}

private final class RecordingCoreDataService: CoreDataServiceProtocol {
    var configuration: CoreDataServiceConfigurationProtocol {
        service.configuration
    }

    private let service: CoreDataServiceProtocol
    private let recorder: RootSetupEventRecorder

    init(
        service: CoreDataServiceProtocol,
        recorder: RootSetupEventRecorder
    ) {
        self.service = service
        self.recorder = recorder
    }

    func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        recorder.record(.storagePreflight)
        service.performAsync(block: block)
    }

    func close() throws {
        try service.close()
    }

    func drop() throws {
        try service.drop()
    }
}

private final class RecordingUserDataStorageTestFacade: UserDataStorageTestFacade {
    private let recorder: RootSetupEventRecorder

    init(recorder: RootSetupEventRecorder) {
        self.recorder = recorder
        super.init()
    }

    override func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        recorder.record(.walletRepository)

        return super.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: mapper
        )
    }
}

private final class FailingUserDataStorageTestFacade: UserDataStorageTestFacade {
    private let error: Error

    init(error: Error) {
        self.error = error
        super.init()
    }

    override func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        let failingService = FailingCoreDataService(
            configuration: databaseService.configuration,
            error: error
        )

        return CoreDataRepository(
            databaseService: failingService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}

private final class FailingCoreDataService: CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol
    private let error: Error

    init(configuration: CoreDataServiceConfigurationProtocol, error: Error) {
        self.configuration = configuration
        self.error = error
    }

    func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        block(nil, error)
    }

    func close() throws {}

    func drop() throws {}
}

private final class ContextProvidingCoreDataService: CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol
    private let context: NSManagedObjectContext?
    private let error: Error?

    init(
        configuration: CoreDataServiceConfigurationProtocol,
        context: NSManagedObjectContext?,
        error: Error? = nil
    ) {
        self.configuration = configuration
        self.context = context
        self.error = error
    }

    func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        block(context, error)
    }

    func close() throws {}

    func drop() throws {}
}

private final class AlertCapturingViewController: UIViewController, RootViewProtocol {
    var onPresent: ((UIViewController) -> Void)?
    private(set) var receivedStates: [RootViewState] = []

    func didReceive(state: RootViewState) {
        receivedStates.append(state)
    }

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated _: Bool,
        completion: (() -> Void)? = nil
    ) {
        onPresent?(viewControllerToPresent)
        completion?()
    }
}

private final class RecordingRootStartupReadinessReporter:
    RootStartupReadinessReporting {
    private let lock = NSLock()
    private var readyEvents = 0
    private var recordedSlowEvents: [RootSetupSlowEvent] = []
    private var recordedFailures: [RootSetupFailure] = []

    var slowEvents: [RootSetupSlowEvent] {
        lock.lock()
        defer { lock.unlock() }

        return recordedSlowEvents
    }

    var failures: [RootSetupFailure] {
        lock.lock()
        defer { lock.unlock() }

        return recordedFailures
    }

    var readyCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return readyEvents
    }

    var failureCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return recordedFailures.count
    }

    func reportSlow(phase: RootSetupPhase, elapsedTime: TimeInterval) {
        lock.lock()
        recordedSlowEvents.append(
            RootSetupSlowEvent(phase: phase, elapsedTime: elapsedTime)
        )
        lock.unlock()
    }

    func reportReady() {
        lock.lock()
        readyEvents += 1
        lock.unlock()
    }

    func reportFailure(_ failure: RootSetupFailure) {
        lock.lock()
        recordedFailures.append(failure)
        lock.unlock()
    }
}

private struct RootSetupSlowEvent: Equatable {
    let phase: RootSetupPhase
    let elapsedTime: TimeInterval
}

private final class StubOnboardingService: OnboardingServiceProtocol {
    private let lock = NSLock()
    private let result: Result<OnboardingConfigPlatform, Error>
    private var callCount = 0

    var fetchCallCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return callCount
    }

    init(result: Result<OnboardingConfigPlatform, Error>) {
        self.result = result
    }

    private func recordFetch() {
        lock.lock()
        callCount += 1
        lock.unlock()
    }

    func fetchConfigs() async throws -> OnboardingConfigPlatform {
        recordFetch()

        return try result.get()
    }
}

private final class LateCompletingOnboardingService: OnboardingServiceProtocol {
    private let lock = NSLock()
    private let startedExpectation: XCTestExpectation
    private var continuation: CheckedContinuation<OnboardingConfigPlatform, Error>?

    init(startedExpectation: XCTestExpectation) {
        self.startedExpectation = startedExpectation
    }

    func fetchConfigs() async throws -> OnboardingConfigPlatform {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()

            startedExpectation.fulfill()
        }
    }

    func succeed(with platform: OnboardingConfigPlatform) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(returning: platform)
    }
}

private extension RootTests {
    static func makeOnboardingPlatform() -> OnboardingConfigPlatform {
        let page: [String: Any] = [
            "description": "Test",
            "image": "https://fearlesswallet.io/onboarding.png"
        ]

        let config: [String: Any] = [
            "new": [page],
            "regular": [page]
        ]

        let wrapper: [String: Any] = [
            "en-EN": config,
            "minVersion": AppVersion.stringValue ?? "0.0.0",
            "background": "https://fearlesswallet.io/background.png"
        ]

        let payload: [String: Any] = ["iOS": [wrapper]]

        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return try! JSONDecoder().decode(OnboardingConfigPlatform.self, from: data)
    }
}
