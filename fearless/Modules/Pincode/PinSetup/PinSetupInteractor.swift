import Foundation
import LocalAuthentication
import SoraKeystore

/// KeychainManager uses a concurrent worker queue. Serialize PIN writes across screen instances
/// so an already-issued older write cannot overwrite a newer PIN after cancellation/navigation.
final class PinSaveCoordinator {
    static let shared = PinSaveCoordinator()
    private var requests: [() -> Void] = []

    func save(
        _ pin: String,
        using secretManager: SecretStoreManagerProtocol,
        isCurrent: @escaping () -> Bool,
        completion: @escaping (Bool) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        requests.append { [weak self] in
            guard let self = self else { return }
            guard isCurrent() else { self.finish(); return }
            var answered = false
            secretManager.saveSecret(pin, for: KeystoreTag.pincode.rawValue, completionQueue: .main) { saved in
                let deliver = {
                    guard !answered else { return }
                    answered = true
                    completion(saved)
                    self.finish()
                }
                if Thread.isMainThread {
                    deliver()
                } else {
                    DispatchQueue.main.async(execute: deliver)
                }
            }
        }
        if requests.count == 1 {
            requests[0]()
        }
    }

    private func finish() {
        requests.removeFirst()
        requests.first?()
    }
}

class PinSetupInteractor {
    enum PinSetupState {
        case waitingPincode
        case waitingBiometrics
        case submitingPincode
        case submitedPincode
        case saveFailed
        case cancelled
    }

    weak var presenter: PinSetupInteractorOutputProtocol?

    private let secretManager: SecretStoreManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    private let biometryAuth: BiometryAuthProtocol
    private let locale: Locale
    private var generation: UInt64 = 0
    private(set) var pincode: String?
    private(set) var state: PinSetupState = .waitingPincode

    init(
        secretManager: SecretStoreManagerProtocol,
        settingsManager: SettingsManagerProtocol,
        biometryAuth: BiometryAuthProtocol,
        locale: Locale
    ) {
        self.secretManager = secretManager
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
        self.locale = locale
    }

    private func onMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    private func changeState(to next: PinSetupState) {
        state = next
        presenter?.didChangeState(to: next)
    }

    private func processBiometry(_ enabled: Bool, attempt: UInt64) {
        guard generation == attempt, state == .waitingBiometrics else { return }
        submitPincode(biometryEnabled: enabled, attempt: attempt)
    }

    private func submitPincode(biometryEnabled: Bool?, attempt: UInt64) {
        guard generation == attempt, let currentPincode = pincode else { return }
        changeState(to: .submitingPincode)
        PinSaveCoordinator.shared.save(
            currentPincode,
            using: secretManager,
            isCurrent: { [weak self, weak output = presenter] in
                guard let self = self, let output = output else { return false }
                return self.generation == attempt && self.state == .submitingPincode && self.presenter === output
            },
            completion: { [weak self, weak output = presenter] saved in
                self?.onMain { [weak self] in
                    guard let self = self, self.generation == attempt, self.state == .submitingPincode,
                          let output = output, self.presenter === output else { return }
                    self.pincode = nil
                    guard saved else {
                        self.changeState(to: .saveFailed)
                        return
                    }
                    // The preference must never claim a usable biometric PIN before storage acknowledges it.
                    if let biometryEnabled = biometryEnabled {
                        self.settingsManager.biometryEnabled = biometryEnabled
                    }
                    self.changeState(to: .submitedPincode)
                    output.didSavePin()
                }
            }
        )
    }
}

extension PinSetupInteractor: PinSetupInteractorInputProtocol {
    func process(pin: String) {
        onMain { [weak self] in
            guard let self = self, self.state == .waitingPincode || self.state == .saveFailed else { return }
            self.generation &+= 1
            let attempt = self.generation
            self.pincode = pin
            switch self.biometryAuth.availableBiometryType {
            case .none:
                self.submitPincode(biometryEnabled: nil, attempt: attempt)
            case .touchId:
                self.changeState(to: .waitingBiometrics)
                self.presenter?.didStartWaitingBiometryDecision(
                    type: .touchId
                ) { [weak self, weak output = self.presenter] enabled in
                    self?.onMain { [weak self] in
                        guard let self = self, let output = output, self.presenter === output else { return }
                        self.processBiometry(enabled, attempt: attempt)
                    }
                }
            case .faceId:
                self.changeState(to: .waitingBiometrics)
                self.biometryAuth.authenticate(
                    localizedReason: R.string.localizable.askBiometryReason(preferredLanguages: self.locale.rLanguages),
                    completionQueue: .main
                ) { [weak self, weak output = self.presenter] enabled in
                    self?.onMain { [weak self] in
                        guard let self = self, let output = output, self.presenter === output else { return }
                        self.processBiometry(enabled, attempt: attempt)
                    }
                }
            }
        }
    }

    func cancel() {
        onMain { [weak self] in
            guard let self = self else { return }
            self.generation &+= 1
            self.pincode = nil
            self.changeState(to: .cancelled)
            self.presenter = nil
        }
    }
}
