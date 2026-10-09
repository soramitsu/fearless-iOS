import Foundation
import CoreData
import SoraKeystore
import IrohaCrypto
import RobinHood
import SoraFoundation

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

enum RootSetupDeadlineError: LocalizedError {
    case migrationTimedOut
    case migrationStillRunning
    case storagePreflightTimedOut
    case selectedWalletSetupTimedOut

    var errorDescription: String? {
        switch self {
        case .migrationTimedOut:
            return "Wallet storage migration timed out"
        case .migrationStillRunning:
            return "Wallet storage migration is still running"
        case .storagePreflightTimedOut:
            return "Substrate storage preflight timed out"
        case .selectedWalletSetupTimedOut:
            return "Selected wallet storage setup timed out"
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

final class RootInteractor {
    private static let setupDeadlineQueue = DispatchQueue(
        label: "jp.co.soramitsu.fearlesswallet.root-setup-deadline",
        qos: .userInitiated
    )

    private enum MigrationBarrierState {
        case notRequested
        case inProgress
        case completed
        case failed(Error)
    }

    private struct MigrationWaiter {
        let generation: UUID
        let completionGate: RootSetupCompletionGate
    }

    weak var presenter: RootInteractorOutputProtocol?

    private let chainRegistryProvider: () -> ChainRegistryProtocol
    private lazy var chainRegistry = chainRegistryProvider()
    private let storagePreflightProvider: RootStoragePreflightProvider
    private let settingsProvider: () -> RootSelectedWalletSettingsProtocol
    private lazy var settings = settingsProvider()
    private let applicationConfig: ApplicationConfigProtocol
    private let eventCenter: EventCenterProtocol
    private let migrators: [Migrating]
    private let logger: LoggerProtocol?
    private let onboardingService: OnboardingServiceProtocol
    private let onboardingConfigResolver: OnboardingConfigVersionResolver
    private let migrationDeadline: TimeInterval
    private let setupDeadline: TimeInterval
    private let setupDeadlineScheduler: RootSetupDeadlineScheduler?
    private let setupQueue = DispatchQueue(
        label: "jp.co.soramitsu.fearlesswallet.root-setup",
        qos: .userInitiated
    )
    // Core Data migration APIs are synchronous and cannot be cancelled safely.
    // Keep exactly one migration worker alive after a presentation deadline so
    // a retry can wait for that same attempt instead of racing a second writer.
    private let migrationInvocationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "jp.co.soramitsu.fearlesswallet.root-migration"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // A Core Data store open cannot be cancelled and may block before
    // `performAsync` returns. Keep one recovery lane, but account for an
    // invocation until both the call returns and its terminal callback arrives.
    // If both lanes stall, retries fail immediately instead of accumulating
    // queued work or opening an unbounded number of concurrent stores. These
    // lanes only perform the read-only preflight; migration writers stay behind
    // the single-worker migration barrier above.
    private let storagePreflightInvocationQueue = DispatchQueue(
        label: "jp.co.soramitsu.fearlesswallet.root-storage-preflight",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let storagePreflightInvocationLimiter =
        RootStoragePreflightInvocationLimiter(maximumInvocationCount: 2)

    private let setupGenerationLock = NSLock()
    private var setupGeneration = UUID()
    // Accessed only on setupQueue. A no-migration reload is an assertion that
    // migrations already completed earlier in this process. Once either path
    // seals the barrier, shared Core Data services may open and migrations must
    // not run again. A required migration failure remains fail-closed until a
    // required retry succeeds.
    private var migrationBarrierState = MigrationBarrierState.notRequested
    private var migrationWaiter: MigrationWaiter?

    init(
        chainRegistryProvider: @escaping () -> ChainRegistryProtocol,
        storagePreflightProvider: @escaping RootStoragePreflightProvider,
        settingsProvider: @escaping () -> RootSelectedWalletSettingsProtocol,
        applicationConfig: ApplicationConfigProtocol,
        eventCenter: EventCenterProtocol,
        migrators: [Migrating],
        logger: LoggerProtocol? = nil,
        onboardingService: OnboardingServiceProtocol,
        onboardingConfigResolver: OnboardingConfigVersionResolver,
        migrationDeadline: TimeInterval = 60,
        setupDeadline: TimeInterval = 15,
        setupDeadlineScheduler: RootSetupDeadlineScheduler? = nil
    ) {
        self.chainRegistryProvider = chainRegistryProvider
        self.storagePreflightProvider = storagePreflightProvider
        self.settingsProvider = settingsProvider
        self.applicationConfig = applicationConfig
        self.eventCenter = eventCenter
        self.migrators = migrators
        self.logger = logger
        self.onboardingService = onboardingService
        self.onboardingConfigResolver = onboardingConfigResolver
        self.migrationDeadline = max(0.001, migrationDeadline)
        self.setupDeadline = max(0.001, setupDeadline)
        self.setupDeadlineScheduler = setupDeadlineScheduler
    }

    deinit {
        migrationInvocationQueue.cancelAllOperations()
    }

    convenience init(
        chainRegistryProvider: @escaping () -> ChainRegistryProtocol,
        storagePreflightProvider: @escaping RootStoragePreflightProvider,
        settings: RootSelectedWalletSettingsProtocol,
        applicationConfig: ApplicationConfigProtocol,
        eventCenter: EventCenterProtocol,
        migrators: [Migrating],
        logger: LoggerProtocol? = nil,
        onboardingService: OnboardingServiceProtocol,
        onboardingConfigResolver: OnboardingConfigVersionResolver,
        migrationDeadline: TimeInterval = 60,
        setupDeadline: TimeInterval = 15,
        setupDeadlineScheduler: RootSetupDeadlineScheduler? = nil
    ) {
        self.init(
            chainRegistryProvider: chainRegistryProvider,
            storagePreflightProvider: storagePreflightProvider,
            settingsProvider: { settings },
            applicationConfig: applicationConfig,
            eventCenter: eventCenter,
            migrators: migrators,
            logger: logger,
            onboardingService: onboardingService,
            onboardingConfigResolver: onboardingConfigResolver,
            migrationDeadline: migrationDeadline,
            setupDeadline: setupDeadline,
            setupDeadlineScheduler: setupDeadlineScheduler
        )
    }

    convenience init(
        chainRegistry: ChainRegistryProtocol,
        storagePreflightProvider: @escaping RootStoragePreflightProvider,
        settings: RootSelectedWalletSettingsProtocol,
        applicationConfig: ApplicationConfigProtocol,
        eventCenter: EventCenterProtocol,
        migrators: [Migrating],
        logger: LoggerProtocol? = nil,
        onboardingService: OnboardingServiceProtocol,
        onboardingConfigResolver: OnboardingConfigVersionResolver,
        migrationDeadline: TimeInterval = 60,
        setupDeadline: TimeInterval = 15,
        setupDeadlineScheduler: RootSetupDeadlineScheduler? = nil
    ) {
        self.init(
            chainRegistryProvider: { chainRegistry },
            storagePreflightProvider: storagePreflightProvider,
            settings: settings,
            applicationConfig: applicationConfig,
            eventCenter: eventCenter,
            migrators: migrators,
            logger: logger,
            onboardingService: onboardingService,
            onboardingConfigResolver: onboardingConfigResolver,
            migrationDeadline: migrationDeadline,
            setupDeadline: setupDeadline,
            setupDeadlineScheduler: setupDeadlineScheduler
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

    private func runMigrators() throws {
        for migrator in migrators {
            try migrator.migrate()
        }
    }

    private func enforceMigrationBarrier(
        runMigrations: Bool,
        generation: UUID
    ) {
        if runMigrations {
            switch migrationBarrierState {
            case .completed:
                preflightStorage(generation: generation)
            case .notRequested, .failed:
                startMigration(generation: generation)
            case .inProgress:
                waitForRunningMigration(generation: generation)
            }
        } else {
            switch migrationBarrierState {
            case .notRequested:
                migrationBarrierState = .completed
                preflightStorage(generation: generation)
            case .completed:
                preflightStorage(generation: generation)
            case .inProgress:
                failSetup(
                    with: RootSetupDeadlineError.migrationStillRunning,
                    generation: generation
                )
            case let .failed(error):
                failSetup(with: error, generation: generation)
            }
        }
    }

    private func startMigration(generation: UUID) {
        migrationBarrierState = .inProgress
        waitForRunningMigration(generation: generation)

        migrationInvocationQueue.addOperation { [weak self] in
            guard let self else {
                return
            }

            let result = Result {
                try self.runMigrators()
            }

            setupQueue.async { [weak self] in
                self?.finishMigration(with: result)
            }
        }
    }

    private func waitForRunningMigration(generation: UUID) {
        let completionGate = RootSetupCompletionGate()
        migrationWaiter = MigrationWaiter(
            generation: generation,
            completionGate: completionGate
        )
        scheduleSetupDeadline(
            after: migrationDeadline,
            generation: generation,
            completionGate: completionGate,
            error: .migrationTimedOut
        )
    }

    private func finishMigration(with result: Result<Void, Error>) {
        let waiter = migrationWaiter
        migrationWaiter = nil

        switch result {
        case .success:
            migrationBarrierState = .completed
        case let .failure(error):
            migrationBarrierState = .failed(error)
        }

        guard
            let waiter,
            waiter.completionGate.claimCompletion(),
            isCurrentSetupGeneration(waiter.generation)
        else {
            return
        }

        switch result {
        case .success:
            preflightStorage(generation: waiter.generation)
        case let .failure(error):
            failSetup(with: error, generation: waiter.generation)
        }
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

    private func completeSetup(generation: UUID) {
        guard isCurrentSetupGeneration(generation) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard self?.isCurrentSetupGeneration(generation) == true else {
                return
            }

            self?.presenter?.didCompleteSetup()
        }
    }

    private func failSetup(with error: Error, generation: UUID) {
        logger?.error(error.localizedDescription)

        guard isCurrentSetupGeneration(generation) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard self?.isCurrentSetupGeneration(generation) == true else {
                return
            }

            self?.presenter?.didFailSetup()
        }
    }

    private func scheduleSetupDeadline(
        after delay: TimeInterval,
        generation: UUID,
        completionGate: RootSetupCompletionGate,
        error: RootSetupDeadlineError
    ) {
        let deadlineAction = { [weak self] in
            guard
                completionGate.claimCompletion(),
                let self,
                isCurrentSetupGeneration(generation)
            else {
                return
            }

            failSetup(with: error, generation: generation)
        }

        if let setupDeadlineScheduler {
            setupDeadlineScheduler(delay, deadlineAction)
        } else {
            Self.setupDeadlineQueue.asyncAfter(
                deadline: .now() + delay,
                execute: deadlineAction
            )
        }
    }

    private func setupSelectedWallet(
        generation: UUID,
        chainRegistry: ChainRegistryProtocol
    ) {
        guard isCurrentSetupGeneration(generation) else {
            return
        }

        let completionGate = RootSetupCompletionGate()
        scheduleSetupDeadline(
            after: setupDeadline,
            generation: generation,
            completionGate: completionGate,
            error: .selectedWalletSetupTimedOut
        )
        settings.setup(runningCompletionIn: .global()) { [weak self] result in
            guard completionGate.claimCompletion() else {
                return
            }

            guard
                let self,
                isCurrentSetupGeneration(generation)
            else {
                return
            }

            setupQueue.async { [weak self] in
                guard
                    let self,
                    isCurrentSetupGeneration(generation)
                else {
                    return
                }

                switch result {
                case let .success(wallet):
                    if let wallet {
                        chainRegistry.performHotBoot()
                        logger?.debug("Selected account: \(wallet.metaId)")
                    } else {
                        chainRegistry.performColdBoot()
                        logger?.debug("No selected account")
                    }

                    completeSetup(generation: generation)
                case let .failure(error):
                    failSetup(with: error, generation: generation)
                }
            }
        }
    }

    private func preflightStorage(generation: UUID) {
        guard isCurrentSetupGeneration(generation) else {
            return
        }

        guard
            let invocation = storagePreflightInvocationLimiter.acquire()
        else {
            failSetup(
                with: RootStoragePreflightError.invocationCapacityExhausted,
                generation: generation
            )
            return
        }

        let completionGate = RootSetupCompletionGate()
        scheduleSetupDeadline(
            after: setupDeadline,
            generation: generation,
            completionGate: completionGate,
            error: .storagePreflightTimedOut
        )
        let preflightProvider = storagePreflightProvider
        storagePreflightInvocationQueue.async { [weak self, invocation] in
            guard
                self?.isCurrentSetupGeneration(generation) == true,
                !completionGate.hasClaimedCompletion()
            else {
                invocation.markSkipped()
                return
            }

            let preflight = preflightProvider()

            guard
                self?.isCurrentSetupGeneration(generation) == true,
                !completionGate.hasClaimedCompletion()
            else {
                invocation.markSkipped()
                return
            }

            preflight.preflight { [weak self] result in
                invocation.markCompletionDelivered()

                guard completionGate.claimCompletion() else {
                    return
                }

                guard let self else {
                    return
                }

                setupQueue.async { [weak self] in
                    guard
                        let self,
                        isCurrentSetupGeneration(generation)
                    else {
                        return
                    }

                    switch result {
                    case .success:
                        let registry = chainRegistry

                        setupSelectedWallet(
                            generation: generation,
                            chainRegistry: registry
                        )
                    case let .failure(error):
                        failSetup(with: error, generation: generation)
                    }
                }
            }

            invocation.markReturned()
        }
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func setup(runMigrations: Bool) {
        setupURLHandlingService()

        let generation = replaceSetupGeneration()

        setupQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard isCurrentSetupGeneration(generation) else {
                return
            }

            enforceMigrationBarrier(
                runMigrations: runMigrations,
                generation: generation
            )
        }
    }

    func fetchOnboardingConfig() async throws -> OnboardingConfigWrapper? {
        do {
            let onboardingConfigPlatform = try await onboardingService.fetchConfigs()
            let onboardingWrappers = onboardingConfigPlatform.ios
            return onboardingConfigResolver.resolve(configWrappers: onboardingWrappers)
        } catch {
            throw error
        }
    }
}
