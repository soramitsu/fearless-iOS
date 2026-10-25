import Foundation
import SoraKeystore

class LocalAuthInteractor {
    enum LocalAuthState {
        case waitingPincode
        case checkingPincode
        case checkingBiometry
        case completed
        case unexpectedFail
    }

    private weak var presenter: LocalAuthInteractorOutputProtocol?
    private(set) var secretManager: SecretStoreManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var biometryAuth: BiometryAuthProtocol
    private(set) var locale: Locale
    private(set) var state = LocalAuthState.waitingPincode
    private(set) var pincode: String?
    private var generation: UInt64 = 0

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

    // State and ownership live on the main queue, including replies from secret/biometric providers.
    private func onMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    private func changeState(to next: LocalAuthState) {
        guard state != next else { return }
        state = next
        presenter?.didChangeState(to: next)
    }

    private func deliver(_ attempt: UInt64, action: @escaping (LocalAuthInteractorOutputProtocol) -> Void) {
        DispatchQueue.main.async { [weak self, weak output = presenter] in
            guard let self = self, self.generation == attempt, let output = output,
                  self.presenter === output else { return }
            action(output)
        }
    }

    private func performBiometryAuth(attempt: UInt64) {
        guard generation == attempt, state == .checkingBiometry else { return }
        guard settingsManager.biometryEnabled == true, biometryAuth.availableBiometryType != .none else {
            changeState(to: .waitingPincode)
            return
        }
        biometryAuth.authenticate(
            localizedReason: R.string.localizable.askBiometryReason(preferredLanguages: locale.rLanguages),
            completionQueue: .main
        ) { [weak self] result in
            self?.onMain { [weak self] in
                self?.processBiometryAuth(result: result, attempt: attempt)
            }
        }
    }

    private func processBiometryAuth(result: Bool, attempt: UInt64) {
        guard generation == attempt, state == .checkingBiometry else { return }
        changeState(to: result ? .completed : .waitingPincode)
        if result { deliver(attempt) { $0.didCompleteAuth() } }
    }

    private func processStored(pin: String?, attempt: UInt64) {
        guard generation == attempt, state == .checkingPincode else { return }
        let matches = pin != nil && pincode == pin
        pincode = nil
        changeState(to: matches ? .completed : .waitingPincode)
        deliver(attempt) { output in
            if matches { output.didCompleteAuth() } else { output.didEnterWrongPincode() }
        }
    }
}

extension LocalAuthInteractor: LocalAuthInteractorInputProtocol {
    var availableBiometryType: AvailableBiometryType {
        biometryAuth.availableBiometryType
    }

    var allowManualBiometryAuth: Bool {
        let touchOrFaceId = availableBiometryType == .touchId || availableBiometryType == .faceId
        return settingsManager.biometryEnabled == true && touchOrFaceId
    }

    func startAuth(with output: LocalAuthInteractorOutputProtocol) {
        onMain { [weak self] in
            guard let self = self else { return }
            if self.presenter !== output {
                self.generation &+= 1
                self.biometryAuth.cancelAuthentication()
                self.pincode = nil
                self.state = .waitingPincode
                self.presenter = output
            }
            guard self.state == .waitingPincode else { return }
            self.generation &+= 1
            let attempt = self.generation
            self.changeState(to: .checkingBiometry)
            self.performBiometryAuth(attempt: attempt)
        }
    }

    func process(pin: String) {
        onMain { [weak self] in
            guard let self = self, self.presenter != nil,
                  self.state == .waitingPincode || self.state == .checkingBiometry else { return }
            self.generation &+= 1
            self.biometryAuth.cancelAuthentication()
            let attempt = self.generation
            self.pincode = pin
            self.changeState(to: .checkingPincode)
            guard self.generation == attempt, self.state == .checkingPincode else { return }
            self.secretManager.loadSecret(
                for: KeystoreTag.pincode.rawValue,
                completionQueue: .main
            ) { [weak self] secret in
                self?.onMain { [weak self] in
                    self?.processStored(pin: secret?.toUTF8String(), attempt: attempt)
                }
            }
        }
    }

    func cancelAuth() {
        onMain { [weak self] in
            guard let self = self else { return }
            self.generation &+= 1
            self.biometryAuth.cancelAuthentication()
            self.pincode = nil
            self.presenter = nil
            self.state = .waitingPincode
        }
    }
}
