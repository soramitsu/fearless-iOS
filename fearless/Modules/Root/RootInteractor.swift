import Foundation
import CoreData
import SoraKeystore
import IrohaCrypto
import RobinHood
import SoraFoundation
import UIKit

enum RootStoragePreflightError: LocalizedError {
    case contextUnavailable
    case persistentStoreCoordinatorUnavailable
    case entityNameUnavailable
    case managedObjectClassNameUnavailable(entityName: String)
    case managedObjectClassUnavailable(entityName: String, className: String)
    case invocationCapacityExhausted
    case unexpectedManagedObjectClassIdentity(
        entityName: String,
        expectedClassName: String,
        actualClassName: String
    )

    var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            return "Substrate storage opened without a managed object context"
        case .persistentStoreCoordinatorUnavailable:
            return "Substrate storage opened without a persistent store coordinator"
        case .entityNameUnavailable:
            return "Substrate storage contains an unnamed entity"
        case let .managedObjectClassNameUnavailable(entityName):
            return "Substrate storage entity \(entityName) has no managed object class"
        case let .managedObjectClassUnavailable(entityName, className):
            return "Substrate storage entity \(entityName) cannot resolve class \(className)"
        case .invocationCapacityExhausted:
            return "Substrate storage preflight is still blocked; retry after the current checks finish"
        case let .unexpectedManagedObjectClassIdentity(
            entityName,
            expectedClassName,
            actualClassName
        ):
            return "Substrate storage entity \(entityName) resolves as \(actualClassName), expected \(expectedClassName)"
        }
    }
}

struct RootSetupMigrationStep {
    let phase: RootSetupPhase
    let migrator: Migrating

    init(phase: RootSetupPhase, migrator: Migrating) {
        self.phase = phase
        self.migrator = migrator
    }
}

protocol RootProtectedDataAvailabilityObservation: AnyObject {
    func invalidate()
}

protocol RootProtectedDataAvailabilityMonitoring: AnyObject {
    var isProtectedDataAvailable: Bool { get }

    func observeDidBecomeAvailable(
        _ action: @escaping () -> Void
    ) -> RootProtectedDataAvailabilityObservation
}

final class RootUIApplicationProtectedDataAvailabilityMonitor:
    RootProtectedDataAvailabilityMonitoring {
    private let application: UIApplication
    private let notificationCenter: NotificationCenter

    init(
        application: UIApplication = .shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.application = application
        self.notificationCenter = notificationCenter
    }

    var isProtectedDataAvailable: Bool {
        application.isProtectedDataAvailable
    }

    func observeDidBecomeAvailable(
        _ action: @escaping () -> Void
    ) -> RootProtectedDataAvailabilityObservation {
        RootNotificationProtectedDataAvailabilityObservation(
            notificationCenter: notificationCenter,
            action: action
        )
    }
}

private final class RootNotificationProtectedDataAvailabilityObservation:
    RootProtectedDataAvailabilityObservation {
    private let lock = NSLock()
    private let notificationCenter: NotificationCenter
    private var observer: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter,
        action: @escaping () -> Void
    ) {
        self.notificationCenter = notificationCenter
        observer = notificationCenter.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: nil
        ) { _ in
            action()
        }
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        lock.lock()
        let observer = observer
        self.observer = nil
        lock.unlock()

        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }
}

protocol RootStoragePreflighting: AnyObject {
    func preflight(
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

typealias RootStoragePreflightProvider = () -> RootStoragePreflighting
typealias RootSetupDeadlineScheduler = (
    TimeInterval,
    @escaping () -> Void
) -> Void
typealias RootMonotonicTimeProvider = () -> TimeInterval

private final class RootSetupCompletionGate {
    private let lock = NSLock()
    private var isCompleted = false

    func hasClaimedCompletion() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return isCompleted
    }

    func claimCompletion() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !isCompleted else {
            return false
        }

        isCompleted = true
        return true
    }
}

private final class RootStoragePreflightInvocation {
    private let lock = NSLock()
    private let finishAction: () -> Void
    private var hasReturned = false
    private var hasDeliveredCompletion = false
    private var isFinished = false

    init(finishAction: @escaping () -> Void) {
        self.finishAction = finishAction
    }

    deinit {
        finish(returned: false, deliveredCompletion: false, force: true)
    }

    func markReturned() {
        finish(returned: true, deliveredCompletion: false, force: false)
    }

    func markCompletionDelivered() {
        finish(returned: false, deliveredCompletion: true, force: false)
    }

    func markSkipped() {
        finish(returned: false, deliveredCompletion: false, force: true)
    }

    private func finish(
        returned: Bool,
        deliveredCompletion: Bool,
        force: Bool
    ) {
        lock.lock()

        hasReturned = hasReturned || returned
        hasDeliveredCompletion =
            hasDeliveredCompletion || deliveredCompletion

        let shouldFinish =
            !isFinished &&
            (force || (hasReturned && hasDeliveredCompletion))

        if shouldFinish {
            isFinished = true
        }

        lock.unlock()

        if shouldFinish {
            finishAction()
        }
    }
}

private final class RootStoragePreflightInvocationLimiter {
    private let lock = NSLock()
    private let maximumInvocationCount: Int
    private var activeInvocationCount = 0

    init(maximumInvocationCount: Int) {
        self.maximumInvocationCount = maximumInvocationCount
    }

    func acquire() -> RootStoragePreflightInvocation? {
        lock.lock()
        defer { lock.unlock() }

        guard activeInvocationCount < maximumInvocationCount else {
            return nil
        }

        activeInvocationCount += 1

        return RootStoragePreflightInvocation { [weak self] in
            self?.release()
        }
    }

    private func release() {
        lock.lock()
        activeInvocationCount = max(0, activeInvocationCount - 1)
        lock.unlock()
    }
}

final class RootCoreDataStoragePreflight: RootStoragePreflighting {
    private let databaseService: CoreDataServiceProtocol

    init(databaseService: CoreDataServiceProtocol) {
        self.databaseService = databaseService
    }

    func preflight(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        databaseService.performAsync { [self] context, error in
            completion(
                Result {
                    try validate(context: context, serviceError: error)
                }
            )
        }
    }

    private func validate(
        context: NSManagedObjectContext?,
        serviceError: Error?
    ) throws {
        if let serviceError {
            throw serviceError
        }

        guard let context else {
            throw RootStoragePreflightError.contextUnavailable
        }

        guard let persistentStoreCoordinator = context.persistentStoreCoordinator else {
            throw RootStoragePreflightError.persistentStoreCoordinatorUnavailable
        }

        let entities = persistentStoreCoordinator.managedObjectModel.entities.sorted {
            ($0.name ?? "") < ($1.name ?? "")
        }

        for entity in entities {
            try validate(entity: entity, in: context)
        }
    }

    private func validate(
        entity: NSEntityDescription,
        in context: NSManagedObjectContext
    ) throws {
        guard let entityName = entity.name else {
            throw RootStoragePreflightError.entityNameUnavailable
        }

        guard let expectedClassName = entity.managedObjectClassName else {
            throw RootStoragePreflightError.managedObjectClassNameUnavailable(
                entityName: entityName
            )
        }

        guard let expectedClass = ManagedObjectRuntimeClassRegistry.resolve(
            className: expectedClassName
        ) else {
            throw RootStoragePreflightError.managedObjectClassUnavailable(
                entityName: entityName,
                className: expectedClassName
            )
        }

        let resolvedClassName = NSStringFromClass(expectedClass)
        guard resolvedClassName == expectedClassName else {
            throw RootStoragePreflightError.unexpectedManagedObjectClassIdentity(
                entityName: entityName,
                expectedClassName: expectedClassName,
                actualClassName: resolvedClassName
            )
        }

        guard !entity.isAbstract else {
            return
        }

        // Fetch only an object ID. Instantiating managed objects or touching their
        // attributes here can decode transformable archives and raise an Objective-C
        // exception that Swift cannot catch. Startup content mapping remains owned by
        // the repositories; this preflight is deliberately limited to store/query and
        // runtime-class availability.
        let request = NSFetchRequest<NSManagedObjectID>(entityName: entityName)
        request.resultType = .managedObjectIDResultType
        request.fetchLimit = 1
        request.includesPendingChanges = false
        request.includesSubentities = false
        _ = try context.fetch(request)
    }
}

protocol RootSelectedWalletSettingsProtocol: AnyObject {
    func setup(
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<MetaAccountModel?, Error>) -> Void)?
    )
}

extension SelectedWalletSettings: RootSelectedWalletSettingsProtocol {}

// Startup migration barriers remain in one state machine.
// swiftlint:disable:next type_body_length
final class RootInteractor {
    private static let setupDeadlineQueue = DispatchQueue(
        label: "jp.co.soramitsu.fearlesswallet.root-setup-deadline",
        qos: .userInitiated
    )

    private struct MigrationStepFailure: Error {
        let phase: RootSetupPhase
        let underlyingError: Error
    }

    private enum MigrationBarrierState {
        case notRequested
        case inProgress
        case completed
        case failed(MigrationStepFailure)
    }

    private struct ProtectedDataWait {
        let identifier: UUID
        let generation: UUID
        let observation: RootProtectedDataAvailabilityObservation
        let action: () -> Void
    }

    weak var presenter: RootInteractorOutputProtocol?

    private let chainRegistryProvider: () -> ChainRegistryProtocol
    private lazy var chainRegistry = chainRegistryProvider()
    private let storagePreflightProvider: RootStoragePreflightProvider
    private let settingsProvider: () -> RootSelectedWalletSettingsProtocol
    private lazy var settings = settingsProvider()
    private let applicationConfig: ApplicationConfigProtocol
    private let eventCenter: EventCenterProtocol
    private let migrationSteps: [RootSetupMigrationStep]
    private let logger: LoggerProtocol?
    private let onboardingService: OnboardingServiceProtocol
    private let onboardingConfigResolver: OnboardingConfigVersionResolver
    private let protectedDataAvailabilityMonitor:
        RootProtectedDataAvailabilityMonitoring
    private let migrationDeadline: TimeInterval
    private let setupDeadline: TimeInterval
    private let setupDeadlineScheduler: RootSetupDeadlineScheduler?
    private let monotonicTimeProvider: RootMonotonicTimeProvider
    private let setupQueue = DispatchQueue(
        label: "jp.co.soramitsu.fearlesswallet.root-setup",
        qos: .userInitiated
    )
    private let migrationInvocationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "jp.co.soramitsu.fearlesswallet.root-migration"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private let storagePreflightInvocationQueue = DispatchQueue(
        label: "jp.co.soramitsu.fearlesswallet.root-storage-preflight",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private let setupGenerationLock = NSLock()
    private var setupGeneration = UUID()

    // The properties below are confined to setupQueue.
    private var isSetupActive = false
    private var setupStartedAt: TimeInterval = 0
    private var currentPhase: RootSetupPhase?
    private var slowThresholdIdentifier: UUID?
    private var protectedDataWait: ProtectedDataWait?
    private var migrationBarrierState = MigrationBarrierState.notRequested

    init(
        chainRegistryProvider: @escaping () -> ChainRegistryProtocol,
        storagePreflightProvider: @escaping RootStoragePreflightProvider,
        settingsProvider: @escaping () -> RootSelectedWalletSettingsProtocol,
        applicationConfig: ApplicationConfigProtocol,
        eventCenter: EventCenterProtocol,
        migrationSteps: [RootSetupMigrationStep],
        logger: LoggerProtocol? = nil,
        onboardingService: OnboardingServiceProtocol,
        onboardingConfigResolver: OnboardingConfigVersionResolver,
        protectedDataAvailabilityMonitor:
        RootProtectedDataAvailabilityMonitoring =
            RootUIApplicationProtectedDataAvailabilityMonitor(),
        migrationDeadline: TimeInterval = 60,
        setupDeadline: TimeInterval = 15,
        setupDeadlineScheduler: RootSetupDeadlineScheduler? = nil,
        monotonicTimeProvider: @escaping RootMonotonicTimeProvider = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.chainRegistryProvider = chainRegistryProvider
        self.storagePreflightProvider = storagePreflightProvider
        self.settingsProvider = settingsProvider
        self.applicationConfig = applicationConfig
        self.eventCenter = eventCenter
        self.migrationSteps = migrationSteps
        self.logger = logger
        self.onboardingService = onboardingService
        self.onboardingConfigResolver = onboardingConfigResolver
        self.protectedDataAvailabilityMonitor =
            protectedDataAvailabilityMonitor
        self.migrationDeadline = max(0.001, migrationDeadline)
        self.setupDeadline = max(0.001, setupDeadline)
        self.setupDeadlineScheduler = setupDeadlineScheduler
        self.monotonicTimeProvider = monotonicTimeProvider
    }

    deinit {
        migrationInvocationQueue.cancelAllOperations()
        protectedDataWait?.observation.invalidate()
    }

    convenience init(
        chainRegistryProvider: @escaping () -> ChainRegistryProtocol,
        storagePreflightProvider: @escaping RootStoragePreflightProvider,
        settings: RootSelectedWalletSettingsProtocol,
        applicationConfig: ApplicationConfigProtocol,
        eventCenter: EventCenterProtocol,
        migrationSteps: [RootSetupMigrationStep],
        logger: LoggerProtocol? = nil,
        onboardingService: OnboardingServiceProtocol,
        onboardingConfigResolver: OnboardingConfigVersionResolver,
        protectedDataAvailabilityMonitor:
        RootProtectedDataAvailabilityMonitoring =
            RootUIApplicationProtectedDataAvailabilityMonitor(),
        migrationDeadline: TimeInterval = 60,
        setupDeadline: TimeInterval = 15,
        setupDeadlineScheduler: RootSetupDeadlineScheduler? = nil,
        monotonicTimeProvider: @escaping RootMonotonicTimeProvider = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.init(
            chainRegistryProvider: chainRegistryProvider,
            storagePreflightProvider: storagePreflightProvider,
            settingsProvider: { settings },
            applicationConfig: applicationConfig,
            eventCenter: eventCenter,
            migrationSteps: migrationSteps,
            logger: logger,
            onboardingService: onboardingService,
            onboardingConfigResolver: onboardingConfigResolver,
            protectedDataAvailabilityMonitor: protectedDataAvailabilityMonitor,
            migrationDeadline: migrationDeadline,
            setupDeadline: setupDeadline,
            setupDeadlineScheduler: setupDeadlineScheduler,
            monotonicTimeProvider: monotonicTimeProvider
        )
    }

    convenience init(
        chainRegistry: ChainRegistryProtocol,
        storagePreflightProvider: @escaping RootStoragePreflightProvider,
        settings: RootSelectedWalletSettingsProtocol,
        applicationConfig: ApplicationConfigProtocol,
        eventCenter: EventCenterProtocol,
        migrationSteps: [RootSetupMigrationStep],
        logger: LoggerProtocol? = nil,
        onboardingService: OnboardingServiceProtocol,
        onboardingConfigResolver: OnboardingConfigVersionResolver,
        protectedDataAvailabilityMonitor:
        RootProtectedDataAvailabilityMonitoring =
            RootUIApplicationProtectedDataAvailabilityMonitor(),
        migrationDeadline: TimeInterval = 60,
        setupDeadline: TimeInterval = 15,
        setupDeadlineScheduler: RootSetupDeadlineScheduler? = nil,
        monotonicTimeProvider: @escaping RootMonotonicTimeProvider = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.init(
            chainRegistryProvider: { chainRegistry },
            storagePreflightProvider: storagePreflightProvider,
            settings: settings,
            applicationConfig: applicationConfig,
            eventCenter: eventCenter,
            migrationSteps: migrationSteps,
            logger: logger,
            onboardingService: onboardingService,
            onboardingConfigResolver: onboardingConfigResolver,
            protectedDataAvailabilityMonitor: protectedDataAvailabilityMonitor,
            migrationDeadline: migrationDeadline,
            setupDeadline: setupDeadline,
            setupDeadlineScheduler: setupDeadlineScheduler,
            monotonicTimeProvider: monotonicTimeProvider
        )
    }

    private func setupURLHandlingService() {
        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

        let callbackUrl = applicationConfig.purchaseRedirect
        let purchaseHandler = PurchaseCompletionHandler(
            callbackUrl: callbackUrl,
            eventCenter: eventCenter
        )

        URLHandlingService.shared.setup(children: [purchaseHandler, keystoreImportService])
    }

    private func replaceSetupGeneration() -> UUID {
        let generation = UUID()

        setupGenerationLock.lock()
        setupGeneration = generation
        setupGenerationLock.unlock()

        return generation
    }

    private func isCurrentSetupGeneration(_ generation: UUID) -> Bool {
        setupGenerationLock.lock()
        defer { setupGenerationLock.unlock() }

        return setupGeneration == generation
    }

    private func beginSetup(runMigrations: Bool) {
        guard !isSetupActive else {
            return
        }

        setupURLHandlingService()

        let generation = replaceSetupGeneration()
        isSetupActive = true
        setupStartedAt = monotonicTimeProvider()
        currentPhase = nil

        enforceMigrationBarrier(
            runMigrations: runMigrations,
            generation: generation
        )
    }

    private func enforceMigrationBarrier(
        runMigrations: Bool,
        generation: UUID
    ) {
        if runMigrations {
            switch migrationBarrierState {
            case .completed:
                beginStoragePreflight(generation: generation)
            case .notRequested, .failed:
                startMigration(generation: generation)
            case .inProgress:
                // An active setup owns the only migration writer. New setup
                // requests are coalesced before reaching this branch.
                break
            }
        } else {
            switch migrationBarrierState {
            case .notRequested:
                migrationBarrierState = .completed
                beginStoragePreflight(generation: generation)
            case .completed:
                beginStoragePreflight(generation: generation)
            case .inProgress:
                // An active setup owns the only migration writer. New setup
                // requests are coalesced before reaching this branch.
                break
            case let .failed(failure):
                failSetup(
                    with: failure.underlyingError,
                    phase: failure.phase,
                    generation: generation
                )
            }
        }
    }

    private func startMigration(generation: UUID) {
        migrationBarrierState = .inProgress

        guard !migrationSteps.isEmpty else {
            migrationBarrierState = .completed
            beginStoragePreflight(generation: generation)
            return
        }

        startMigrationStep(at: 0, generation: generation)
    }

    private func startMigrationStep(at index: Int, generation: UUID) {
        guard migrationSteps.indices.contains(index) else {
            migrationBarrierState = .completed
            beginStoragePreflight(generation: generation)
            return
        }

        let step = migrationSteps[index]
        performWhenProtectedDataIsAvailable(
            generation: generation
        ) { [weak self] in
            self?.invokeMigrationStep(
                step,
                at: index,
                generation: generation
            )
        }
    }

    private func invokeMigrationStep(
        _ step: RootSetupMigrationStep,
        at index: Int,
        generation: UUID
    ) {
        guard isActiveSetup(generation: generation) else {
            return
        }

        updateSetupPhase(step.phase, generation: generation)
        if index == migrationSteps.startIndex {
            scheduleSlowThreshold(
                after: migrationDeadline,
                generation: generation
            )
        }

        migrationInvocationQueue.addOperation { [weak self] in
            let result = Result {
                try step.migrator.migrate()
            }

            self?.setupQueue.async { [weak self] in
                guard let self, isActiveSetup(generation: generation) else {
                    return
                }

                switch result {
                case .success:
                    startMigrationStep(
                        at: index + 1,
                        generation: generation
                    )
                case let .failure(error):
                    let failure = MigrationStepFailure(
                        phase: step.phase,
                        underlyingError: error
                    )
                    migrationBarrierState = .failed(failure)
                    failSetup(
                        with: error,
                        phase: step.phase,
                        generation: generation
                    )
                }
            }
        }
    }

    private func beginStoragePreflight(generation: UUID) {
        invalidateSlowThreshold()
        performWhenProtectedDataIsAvailable(
            generation: generation
        ) { [weak self] in
            self?.invokeStoragePreflight(generation: generation)
        }
    }

    private func invokeStoragePreflight(generation: UUID) {
        guard isActiveSetup(generation: generation) else {
            return
        }

        updateSetupPhase(.substratePreflight, generation: generation)
        scheduleSlowThreshold(after: setupDeadline, generation: generation)

        let preflight = storagePreflightProvider()
        let completionGate = RootSetupCompletionGate()

        storagePreflightInvocationQueue.async { [weak self] in
            guard
                self?.isCurrentSetupGeneration(generation) == true,
                !completionGate.hasClaimedCompletion()
            else {
                return
            }

            preflight.preflight { [weak self] result in
                guard completionGate.claimCompletion(), let self else {
                    return
                }

                setupQueue.async { [weak self] in
                    guard let self, isActiveSetup(generation: generation) else {
                        return
                    }

                    switch result {
                    case .success:
                        beginSelectedWalletOpening(generation: generation)
                    case let .failure(error):
                        failSetup(
                            with: error,
                            phase: .substratePreflight,
                            generation: generation
                        )
                    }
                }
            }
        }
    }

    private func beginSelectedWalletOpening(generation: UUID) {
        invalidateSlowThreshold()
        performWhenProtectedDataIsAvailable(
            generation: generation
        ) { [weak self] in
            self?.invokeSelectedWalletOpening(generation: generation)
        }
    }

    private func invokeSelectedWalletOpening(generation: UUID) {
        guard isActiveSetup(generation: generation) else {
            return
        }

        updateSetupPhase(.selectedWalletOpening, generation: generation)
        scheduleSlowThreshold(after: setupDeadline, generation: generation)

        let registry = chainRegistry
        let selectedWalletSettings = settings
        let completionGate = RootSetupCompletionGate()

        selectedWalletSettings.setup(
            runningCompletionIn: .global()
        ) { [weak self] result in
            guard completionGate.claimCompletion(), let self else {
                return
            }

            setupQueue.async { [weak self] in
                guard let self, isActiveSetup(generation: generation) else {
                    return
                }

                switch result {
                case let .success(wallet):
                    if wallet != nil {
                        registry.performHotBoot()
                    } else {
                        registry.performColdBoot()
                    }

                    logger?.debug("Selected wallet setup completed")
                    completeSetup(generation: generation)
                case let .failure(error):
                    failSetup(
                        with: error,
                        phase: .selectedWalletOpening,
                        generation: generation
                    )
                }
            }
        }
    }

    private func performWhenProtectedDataIsAvailable(
        generation: UUID,
        action: @escaping () -> Void
    ) {
        guard isActiveSetup(generation: generation) else {
            return
        }

        protectedDataWait?.observation.invalidate()

        let identifier = UUID()
        let observation = protectedDataAvailabilityMonitor
            .observeDidBecomeAvailable { [weak self] in
                self?.setupQueue.async { [weak self] in
                    self?.resumeProtectedDataWait(identifier: identifier)
                }
            }

        protectedDataWait = ProtectedDataWait(
            identifier: identifier,
            generation: generation,
            observation: observation,
            action: action
        )

        // Register first, then inspect availability so an unlock racing this
        // check cannot be missed.
        if protectedDataAvailabilityMonitor.isProtectedDataAvailable {
            setupQueue.async { [weak self] in
                self?.resumeProtectedDataWait(identifier: identifier)
            }
        }
    }

    private func resumeProtectedDataWait(identifier: UUID) {
        guard
            let wait = protectedDataWait,
            wait.identifier == identifier,
            protectedDataAvailabilityMonitor.isProtectedDataAvailable
        else {
            return
        }

        protectedDataWait = nil
        wait.observation.invalidate()

        guard isActiveSetup(generation: wait.generation) else {
            return
        }

        wait.action()
    }

    private func scheduleSlowThreshold(
        after delay: TimeInterval,
        generation: UUID
    ) {
        let identifier = UUID()
        slowThresholdIdentifier = identifier

        let thresholdAction: () -> Void = { [weak self] in
            guard let self else {
                return
            }

            setupQueue.async { [weak self] in
                guard
                    let self,
                    slowThresholdIdentifier == identifier,
                    isActiveSetup(generation: generation),
                    let phase = currentPhase
                else {
                    return
                }

                slowThresholdIdentifier = nil
                deliverSetupState(
                    .slow(phase, elapsedTime: elapsedTime()),
                    generation: generation
                )
            }
        }

        if let setupDeadlineScheduler {
            setupDeadlineScheduler(delay, thresholdAction)
        } else {
            Self.setupDeadlineQueue.asyncAfter(
                deadline: .now() + delay,
                execute: thresholdAction
            )
        }
    }

    private func invalidateSlowThreshold() {
        slowThresholdIdentifier = nil
    }

    private func updateSetupPhase(
        _ phase: RootSetupPhase,
        generation: UUID
    ) {
        guard isActiveSetup(generation: generation) else {
            return
        }

        currentPhase = phase
        deliverSetupState(.running(phase), generation: generation)
    }

    private func elapsedTime() -> TimeInterval {
        max(0, monotonicTimeProvider() - setupStartedAt)
    }

    private func isActiveSetup(generation: UUID) -> Bool {
        isSetupActive && isCurrentSetupGeneration(generation)
    }

    private func completeSetup(generation: UUID) {
        guard isActiveSetup(generation: generation) else {
            return
        }

        finishActiveSetup()
        deliverSetupState(.ready, generation: generation)
    }

    private func failSetup(
        with error: Error,
        phase: RootSetupPhase,
        generation: UUID
    ) {
        guard isActiveSetup(generation: generation) else {
            return
        }

        let failure = makeSetupFailure(
            error: error,
            phase: phase,
            elapsedTime: elapsedTime()
        )
        logger?.error(
            "Root setup failed with incident \(failure.incidentCode.rawValue)"
        )

        finishActiveSetup()

        DispatchQueue.main.async { [weak self] in
            guard self?.isCurrentSetupGeneration(generation) == true else {
                return
            }

            self?.presenter?.didUpdateSetup(.failed(failure))
            self?.presenter?.didFailSetup(failure)
        }
    }

    private func finishActiveSetup() {
        invalidateSlowThreshold()
        protectedDataWait?.observation.invalidate()
        protectedDataWait = nil
        currentPhase = nil
        isSetupActive = false
    }

    private func deliverSetupState(
        _ state: RootSetupState,
        generation: UUID
    ) {
        DispatchQueue.main.async { [weak self] in
            guard self?.isCurrentSetupGeneration(generation) == true else {
                return
            }

            self?.presenter?.didUpdateSetup(state)
        }
    }

    private func makeSetupFailure(
        error: Error,
        phase: RootSetupPhase,
        elapsedTime: TimeInterval
    ) -> RootSetupFailure {
        if let requiredByteCount = requiredFreeStorageByteCount(in: error) {
            return RootSetupFailure(
                phase: phase,
                incidentCode: .insufficientStorage,
                elapsedTime: elapsedTime,
                recoveryAction: .freeStorage(
                    requiredByteCount: requiredByteCount
                )
            )
        }

        let incidentCode = incidentCode(for: error, phase: phase)
        let recoveryAction: RootSetupRecoveryAction
        switch incidentCode {
        case .userStorageCompatibilityMissing,
             .userStorageIntegrityRejected,
             .substrateCompatibilityMissing,
             .substrateIntegrityRejected,
             .substratePreflightCompatibilityMissing,
             .walletMappingConflict,
             .walletRecordRejected:
            recoveryAction = .installLatestBuild
        case .languageMigrationFailed,
             .userStorageMigrationFailed,
             .substrateMigrationFailed,
             .substratePreflightFailed,
             .selectedWalletOpeningFailed,
             .insufficientStorage:
            recoveryAction = .retry
        }

        return RootSetupFailure(
            phase: phase,
            incidentCode: incidentCode,
            elapsedTime: elapsedTime,
            recoveryAction: recoveryAction
        )
    }

    private func incidentCode(
        for error: Error,
        phase: RootSetupPhase
    ) -> RootSetupIncidentCode {
        switch phase {
        case .languageMigration:
            return .languageMigrationFailed
        case .userStorageMigration:
            if containsError(error, matching: isIntegrityError) {
                return .userStorageIntegrityRejected
            }

            if let migrationError = error as? UserStorageMigrationError {
                switch migrationError {
                case .unknownStoreVersion,
                     .modelUnavailable,
                     .migrationPathUnavailable:
                    return .userStorageCompatibilityMissing
                case .metadataUnreadable,
                     .objectiveCException,
                     .privateSourceRepairFailed,
                     .stagedStoreValidationFailed:
                    break
                }
            }

            return .userStorageMigrationFailed
        case .substrateMigration:
            if containsError(error, matching: isIntegrityError) {
                return .substrateIntegrityRejected
            }

            if let migrationError = error as? SubstrateStorageMigrationError {
                switch migrationError {
                case .unknownStoreVersion,
                     .modelUnavailable,
                     .migrationPathUnavailable,
                     .mappingUnavailable:
                    return .substrateCompatibilityMissing
                default:
                    break
                }
            }

            return .substrateMigrationFailed
        case .substratePreflight:
            if let preflightError = error as? RootStoragePreflightError {
                switch preflightError {
                case .managedObjectClassNameUnavailable,
                     .managedObjectClassUnavailable,
                     .unexpectedManagedObjectClassIdentity:
                    return .substratePreflightCompatibilityMissing
                case .contextUnavailable,
                     .persistentStoreCoordinatorUnavailable,
                     .entityNameUnavailable,
                     .invocationCapacityExhausted:
                    break
                }
            }

            return .substratePreflightFailed
        case .selectedWalletOpening:
            if error is SelectedWalletSettingsError {
                return .walletMappingConflict
            }

            if error is MetaAccountMapperError {
                return .walletRecordRejected
            }

            return .selectedWalletOpeningFailed
        }
    }

    private func isIntegrityError(_ error: Error) -> Bool {
        if error is SQLiteStoreQuickCheckError {
            return true
        }

        if let migrationError = error as? UserStorageMigrationError {
            switch migrationError {
            case .objectiveCException,
                 .privateSourceRepairFailed,
                 .stagedStoreValidationFailed:
                return true
            case .metadataUnreadable,
                 .unknownStoreVersion,
                 .modelUnavailable,
                 .migrationPathUnavailable:
                return false
            }
        }

        if let migrationError = error as? SubstrateStorageMigrationError {
            switch migrationError {
            case .transformableSanitizationFailed,
                 .unsupportedTransformableAttribute,
                 .objectiveCException,
                 .sourceStoreInspectionFailed,
                 .protectedDataInspectionRejected,
                 .stagedStoreInvalid,
                 .stagedStoreInspectionFailed,
                 .stagedStoreRowCountMismatch,
                 .stagedStoreProtectedDataMismatch,
                 .cacheRecoveryBlockedByProtectedData:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func requiredFreeStorageByteCount(in error: Error) -> UInt64? {
        if let replacementError = error as? CrashConsistentStoreReplacementError {
            if case let .insufficientStorageCapacity(
                requiredByteCount,
                _
            ) = replacementError {
                return requiredByteCount
            }
        }

        for nestedError in nestedErrors(in: error) {
            if let requiredByteCount = requiredFreeStorageByteCount(
                in: nestedError
            ) {
                return requiredByteCount
            }
        }

        return nil
    }

    private func containsError(
        _ error: Error,
        matching predicate: (Error) -> Bool,
        remainingDepth: Int = 8
    ) -> Bool {
        guard remainingDepth > 0 else {
            return false
        }

        if predicate(error) {
            return true
        }

        return nestedErrors(in: error).contains { nestedError in
            containsError(
                nestedError,
                matching: predicate,
                remainingDepth: remainingDepth - 1
            )
        }
    }

    private func nestedErrors(in error: Error) -> [Error] {
        if let replacementError = error as? CrashConsistentStoreReplacementError {
            switch replacementError {
            case let .destinationValidationFailed(error):
                return [error]
            case let .rollbackFailed(replacementError, rollbackError):
                return [replacementError, rollbackError]
            case let .fileSynchronizationFailed(_, error),
                 let .directorySynchronizationFailed(_, error):
                return [error]
            default:
                return []
            }
        }

        if let migrationError = error as? UserStorageMigrationError {
            if case let .metadataUnreadable(_, error) = migrationError {
                return [error]
            }

            return []
        }

        if let migrationError = error as? SubstrateStorageMigrationError {
            switch migrationError {
            case let .metadataUnreadable(_, error),
                 let .sourceSnapshotFailed(_, error),
                 let .walCheckpointFailed(_, error),
                 let .transformableSanitizationFailed(_, error),
                 let .temporaryDirectoryCreationFailed(_, error),
                 let .temporaryStoreCleanupFailed(_, error),
                 let .sourceStoreInspectionFailed(_, error),
                 let .protectedDataInspectionRejected(_, error),
                 let .stagedStoreMetadataUnreadable(_, error),
                 let .stagedStoreInspectionFailed(_, error),
                 let .storeReplacementFailed(_, error),
                 let .pendingCacheRecoveryFailed(_, error):
                return [error]
            case let .mappingUnavailable(_, _, error),
                 let .migrationStepFailed(_, _, error):
                return [error]
            case let .cacheRecoveryBlockedByProtectedData(
                _,
                migrationError,
                _
            ):
                return [migrationError]
            case let .cacheRecoveryFailed(
                _,
                migrationError,
                recoveryError
            ):
                return [migrationError, recoveryError]
            default:
                return []
            }
        }

        return []
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func setup(runMigrations: Bool) {
        setupQueue.async { [weak self] in
            self?.beginSetup(runMigrations: runMigrations)
        }
    }

    func fetchOnboardingConfig() async throws -> OnboardingConfigWrapper? {
        let onboardingConfigPlatform = try await onboardingService.fetchConfigs()
        let onboardingWrappers = onboardingConfigPlatform.ios
        return onboardingConfigResolver.resolve(configWrappers: onboardingWrappers)
    }
}
