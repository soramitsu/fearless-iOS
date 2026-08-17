import UIKit
import SoraFoundation
import os.log

protocol RootStartupReadinessReporting: AnyObject {
    func reportSlow(phase: RootSetupPhase, elapsedTime: TimeInterval)
    func reportReady()
    func reportFailure(_ failure: RootSetupFailure)
}

final class RootStartupReadinessReporter: RootStartupReadinessReporting {
    static let shared = RootStartupReadinessReporter()

    private let log: OSLog
    private let readyMarkerEmitter: (OSLog) -> Void
    private let lock = NSLock()
    private var hasReportedReady = false

    init(
        log: OSLog = OSLog(
            subsystem: Bundle.main.bundleIdentifier ?? "jp.co.soramitsu.fearlesswallet",
            category: "startup-readiness"
        ),
        readyMarkerEmitter: @escaping (OSLog) -> Void = {
            os_log("FEARLESS_STARTUP_READY", log: $0, type: .default)
        }
    ) {
        self.log = log
        self.readyMarkerEmitter = readyMarkerEmitter
    }

    func reportSlow(phase: RootSetupPhase, elapsedTime: TimeInterval) {
        os_log(
            "FEARLESS_STARTUP_SLOW phase=%{public}@ elapsed_ms=%{public}llu",
            log: log,
            type: .default,
            phase.rawValue as NSString,
            Self.elapsedMilliseconds(elapsedTime)
        )
    }

    func reportReady() {
        lock.lock()
        guard !hasReportedReady else {
            lock.unlock()
            return
        }
        hasReportedReady = true
        lock.unlock()

        readyMarkerEmitter(log)
    }

    func reportFailure(_ failure: RootSetupFailure) {
        let recovery = failure.recoveryAction.startupLogFields
        os_log(
            """
            FEARLESS_STARTUP_FAILED phase=%{public}@ code=%{public}@ \
            elapsed_ms=%{public}llu recovery=%{public}@ required_free_bytes=%{public}llu
            """,
            log: log,
            type: .error,
            failure.phase.rawValue as NSString,
            failure.incidentCode.rawValue as NSString,
            Self.elapsedMilliseconds(failure.elapsedTime),
            recovery.name as NSString,
            recovery.requiredFreeByteCount
        )
    }

    private static func elapsedMilliseconds(_ elapsedTime: TimeInterval) -> UInt64 {
        let milliseconds = max(0, elapsedTime) * 1000
        return UInt64(min(milliseconds, Double(UInt64.max)))
    }
}

final class RootPresenter {
    private enum SetupPurpose {
        case launch
        case reload
    }

    private enum LoadError: LocalizedError {
        case missingInteractor
        case onboardingConfigTimedOut

        var errorDescription: String? {
            switch self {
            case .missingInteractor:
                return "Root interactor is unavailable"
            case .onboardingConfigTimedOut:
                return "Onboarding configuration request timed out"
            }
        }
    }

    var view: ControllerBackedProtocol?
    var window: UIWindow!
    var wireframe: RootWireframeProtocol!
    var interactor: RootInteractorInputProtocol!

    private let startViewHelper: StartViewHelperProtocol
    private let onboardingConfigTimeoutNanoseconds: UInt64
    private let startupReadinessReporter: RootStartupReadinessReporting
    private var loadTask: Task<Void, Never>?
    private var setupPurpose: SetupPurpose?
    private var setupStartedAt: TimeInterval?
    private var isShowingSlowMessage = false

    init(
        localizationManager: LocalizationManagerProtocol,
        startViewHelper: StartViewHelperProtocol,
        onboardingConfigTimeoutNanoseconds: UInt64 = 5_000_000_000,
        startupReadinessReporter: RootStartupReadinessReporting =
            RootStartupReadinessReporter.shared
    ) {
        self.startViewHelper = startViewHelper
        self.onboardingConfigTimeoutNanoseconds = max(1, onboardingConfigTimeoutNanoseconds)
        self.startupReadinessReporter = startupReadinessReporter
        self.localizationManager = localizationManager
    }

    deinit {
        loadTask?.cancel()
    }

    private func decideModuleSynchroniously(with onboardingConfig: OnboardingConfigWrapper?) {
        do {
            let startView = try startViewHelper.startView(
                onboardingConfig: onboardingConfig
            )
            switch startView {
            case .pin:
                wireframe.showLocalAuthentication(on: window)
                startupReadinessReporter.reportReady()
            case .pinSetup:
                wireframe.showPincodeSetup(on: window)
                startupReadinessReporter.reportReady()
            case .login:
                wireframe.showMain(on: window)
                startupReadinessReporter.reportReady()
            case let .onboarding(config):
                wireframe.showOnboarding(on: window, with: config)
                startupReadinessReporter.reportReady()
            }
        } catch {
            wireframe.showBroken(on: window)
            let failure = makePostSetupFailure(error: error)
            startupReadinessReporter.reportFailure(failure)
            showSetupFailure(failure)
        }
    }

    private func makePostSetupFailure(error: Error) -> RootSetupFailure {
        let incidentCode: RootSetupIncidentCode
        let recoveryAction: RootSetupRecoveryAction
        if error is StartViewError {
            incidentCode = .walletRecordRejected
            recoveryAction = .installLatestBuild
        } else {
            incidentCode = .selectedWalletOpeningFailed
            recoveryAction = .retry
        }

        return RootSetupFailure(
            phase: .selectedWalletOpening,
            incidentCode: incidentCode,
            elapsedTime: setupStartedAt.map {
                max(0, ProcessInfo.processInfo.systemUptime - $0)
            } ?? 0,
            recoveryAction: recoveryAction
        )
    }

    private func fetchOnboardingConfigWithTimeout() async throws -> OnboardingConfigWrapper? {
        try Task.checkCancellation()

        let raceState = RootAsyncRaceState<OnboardingConfigWrapper?>()
        let timeout = onboardingConfigTimeoutNanoseconds

        guard let interactor else {
            throw LoadError.missingInteractor
        }

        return try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    guard raceState.install(continuation), !Task.isCancelled else {
                        raceState.resolve(.failure(CancellationError()))
                        return
                    }

                    let fetchTask = Task {
                        guard raceState.claimOperationStart() else {
                            return
                        }

                        do {
                            raceState.resolve(.success(try await interactor.fetchOnboardingConfig()))
                        } catch {
                            raceState.resolve(.failure(error))
                        }
                    }

                    let timeoutTask = Task {
                        do {
                            try await Task.sleep(nanoseconds: timeout)
                            raceState.resolve(.failure(LoadError.onboardingConfigTimedOut))
                        } catch {
                            // The other result won the race or startup was cancelled.
                        }
                    }

                    raceState.registerTasks([fetchTask, timeoutTask])
                }
            },
            onCancel: {
                raceState.resolve(.failure(CancellationError()))
            }
        )
    }

    private func loadOnboardingConfig() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let onboardingConfig = try await fetchOnboardingConfigWithTimeout()
                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    guard !Task.isCancelled else { return }

                    self?.decideModuleSynchroniously(with: onboardingConfig)
                }
            } catch {
                guard !Task.isCancelled else { return }

                Logger.shared.error(error.localizedDescription)
                await MainActor.run { [weak self] in
                    guard !Task.isCancelled else { return }

                    self?.decideModuleSynchroniously(with: nil)
                }
            }
        }
    }

    private func showRetryableFailure(message: String) {
        let title = R.string.localizable.commonErrorGeneralTitle(
            preferredLanguages: localizationManager?.selectedLocale.rLanguages
        )
        let retryTitle = R.string.localizable.commonRetry(
            preferredLanguages: localizationManager?.selectedLocale.rLanguages
        )

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: retryTitle, style: .default) { [weak self] _ in
                self?.loadOnLaunch()
            }
        )

        view?.controller.present(alert, animated: true)
    }

    private func showSetupFailure(_ failure: RootSetupFailure) {
        let guidance: String
        switch failure.phase {
        case .languageMigration:
            guidance = "Fearless couldn't finish preparing your language settings."
        case .userStorageMigration:
            guidance = """
            Fearless couldn't update your wallet storage safely. Your existing wallet data was not replaced.
            """
        case .substrateMigration:
            guidance = """
            Fearless couldn't update network storage safely. Your existing wallet data was not replaced.
            """
        case .substratePreflight:
            guidance = """
            Fearless couldn't verify network storage. Your existing wallet data was not changed.
            """
        case .selectedWalletOpening:
            guidance = """
            Fearless couldn't open your selected wallet. Your existing wallet data was not changed.
            """
        }

        let recovery: String
        switch failure.recoveryAction {
        case .retry:
            recovery = "Keep the device unlocked, then retry once."
        case .installLatestBuild:
            recovery = "Install the latest Fearless build, then retry once."
        case let .freeStorage(requiredByteCount):
            let requiredSpace = ByteCountFormatter.string(
                fromByteCount: Int64(clamping: requiredByteCount),
                countStyle: .file
            )
            recovery = "Free at least \(requiredSpace) of storage, then retry once."
        }

        showRetryableFailure(
            message: """
            \(guidance)

            \(recovery)
            Incident code: \(failure.incidentCode.rawValue)
            """
        )
    }
}

extension RootPresenter: RootPresenterProtocol {
    func loadOnLaunch() {
        wireframe.showSplash(splashView: view, on: window)

        loadTask?.cancel()
        if setupPurpose == nil {
            setupPurpose = .launch
            setupStartedAt = ProcessInfo.processInfo.systemUptime
            isShowingSlowMessage = false
            (view as? RootViewProtocol)?.didReceive(state: .plain)
        }
        interactor.setup(runMigrations: true)
    }

    func reload() {
        loadTask?.cancel()
        if setupPurpose == nil {
            setupPurpose = .reload
            setupStartedAt = ProcessInfo.processInfo.systemUptime
            isShowingSlowMessage = false
            (view as? RootViewProtocol)?.didReceive(state: .plain)
        }
        interactor.setup(runMigrations: false)
    }
}

extension RootPresenter: RootInteractorOutputProtocol {
    func didUpdateSetup(_ state: RootSetupState) {
        switch state {
        case .running:
            if !isShowingSlowMessage {
                (view as? RootViewProtocol)?.didReceive(state: .plain)
            }
        case let .slow(phase, elapsedTime):
            isShowingSlowMessage = true
            startupReadinessReporter.reportSlow(
                phase: phase,
                elapsedTime: elapsedTime
            )
            (view as? RootViewProtocol)?.didReceive(
                state: .updating(
                    message: "Updating/opening your wallet—keep Fearless open."
                )
            )
        case .ready:
            guard let setupPurpose else {
                return
            }

            self.setupPurpose = nil
            isShowingSlowMessage = false
            (view as? RootViewProtocol)?.didReceive(state: .plain)

            switch setupPurpose {
            case .launch:
                loadOnboardingConfig()
            case .reload:
                decideModuleSynchroniously(with: nil)
            }
        case .failed:
            break
        }
    }

    func didFailSetup(_ failure: RootSetupFailure) {
        setupPurpose = nil
        loadTask?.cancel()
        isShowingSlowMessage = false
        (view as? RootViewProtocol)?.didReceive(state: .plain)
        startupReadinessReporter.reportFailure(failure)
        showSetupFailure(failure)
    }
}

extension RootPresenter: Localizable {
    func applyLocalization() {}
}

private extension RootSetupRecoveryAction {
    var startupLogFields: (name: String, requiredFreeByteCount: UInt64) {
        switch self {
        case .retry:
            return ("retry", 0)
        case .installLatestBuild:
            return ("install_latest_build", 0)
        case let .freeStorage(requiredByteCount):
            return ("free_storage", requiredByteCount)
        }
    }
}

/// An unstructured first-result race is intentional. Structured task groups wait for cancelled
/// children before returning, so a transport that ignores cancellation could defeat the deadline.
private final class RootAsyncRaceState<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var resolution: Result<Value, Error>?
    private var tasks: [Task<Void, Never>] = []
    private var operationStarted = false

    @discardableResult
    func install(_ continuation: CheckedContinuation<Value, Error>) -> Bool {
        lock.lock()

        if let resolution {
            lock.unlock()
            continuation.resume(with: resolution)
            return false
        } else {
            self.continuation = continuation
            lock.unlock()
            return true
        }
    }

    func claimOperationStart() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard resolution == nil, !operationStarted else {
            return false
        }

        operationStarted = true
        return true
    }

    func registerTasks(_ tasks: [Task<Void, Never>]) {
        lock.lock()

        if resolution == nil {
            self.tasks = tasks
            lock.unlock()
        } else {
            lock.unlock()
            tasks.forEach { $0.cancel() }
        }
    }

    func resolve(_ result: Result<Value, Error>) {
        lock.lock()

        guard resolution == nil else {
            lock.unlock()
            return
        }

        resolution = result
        let continuation = continuation
        self.continuation = nil
        let tasks = tasks
        self.tasks.removeAll()
        lock.unlock()

        tasks.forEach { $0.cancel() }
        continuation?.resume(with: result)
    }
}
