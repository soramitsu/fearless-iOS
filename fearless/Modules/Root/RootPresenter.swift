import UIKit
import SoraFoundation
import os.log

protocol RootStartupReadinessReporting: AnyObject {
    func reportReady()
    func reportFailure()
}

final class RootStartupReadinessReporter: RootStartupReadinessReporting {
    static let shared = RootStartupReadinessReporter()

    private let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "jp.co.soramitsu.fearlesswallet",
        category: "startup-readiness"
    )

    private init() {}

    func reportReady() {
        os_log("FEARLESS_STARTUP_READY", log: log, type: .default)
    }

    func reportFailure() {
        os_log("FEARLESS_STARTUP_FAILED", log: log, type: .error)
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
        let startView = startViewHelper.startView(onboardingConfig: onboardingConfig)
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
        case .broken:
            wireframe.showBroken(on: window)
            startupReadinessReporter.reportFailure()
            showProtectedDataFailure()
        case .unsupportedWallet:
            wireframe.showBroken(on: window)
            startupReadinessReporter.reportFailure()
            showUnsupportedWalletFailure()
        case let .onboarding(config):
            wireframe.showOnboarding(on: window, with: config)
            startupReadinessReporter.reportReady()
        }
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

    private func showSetupFailure() {
        showRetryableFailure(
            message: """
            Your wallet data is safe, but Fearless Wallet couldn't update it. \
            Please retry or install the latest build.
            """
        )
    }

    private func showProtectedDataFailure() {
        showRetryableFailure(
            message: """
            Your wallet data is safe, but Fearless Wallet couldn't access its protected security data. \
            Unlock your device and retry. If this continues, restart your device.
            """
        )
    }

    private func showUnsupportedWalletFailure() {
        showRetryableFailure(
            message: """
            Your wallet data is safe, but this build can't open any of the wallets stored on this device. \
            Please install the latest build and retry.
            """
        )
    }
}

extension RootPresenter: RootPresenterProtocol {
    func loadOnLaunch() {
        wireframe.showSplash(splashView: view, on: window)

        loadTask?.cancel()
        setupPurpose = .launch
        interactor.setup(runMigrations: true)
    }

    func reload() {
        loadTask?.cancel()
        setupPurpose = .reload
        interactor.setup(runMigrations: false)
    }
}

extension RootPresenter: RootInteractorOutputProtocol {
    func didCompleteSetup() {
        guard let setupPurpose else {
            return
        }

        self.setupPurpose = nil

        switch setupPurpose {
        case .launch:
            loadOnboardingConfig()
        case .reload:
            decideModuleSynchroniously(with: nil)
        }
    }

    func didFailSetup() {
        setupPurpose = nil
        loadTask?.cancel()
        startupReadinessReporter.reportFailure()
        showSetupFailure()
    }
}

extension RootPresenter: Localizable {
    func applyLocalization() {}
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
