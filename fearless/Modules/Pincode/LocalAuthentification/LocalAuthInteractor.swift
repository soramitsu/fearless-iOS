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

    private(set) var state = LocalAuthState.waitingPincode {
        didSet(oldValue) {
            if oldValue != state {
                DispatchQueue.main.async {
                    self.presenter?.didChangeState(to: self.state)
                }
            }
        }
    }

    private(set) var pincode: String?

    private func performBiometryAuth() {
        guard state == .checkingBiometry else { return }

        let biometryUsageOptional = settingsManager.biometryEnabled

        guard let biometryUsage = biometryUsageOptional, biometryUsage else {
            state = .waitingPincode
            return
        }

        guard biometryAuth.availableBiometryType != .none else {
            state = .waitingPincode
            return
        }

        biometryAuth.authenticate(
            localizedReason: R.string.localizable.askBiometryReason(preferredLanguages: locale.rLanguages),
            completionQueue: .global(qos: .userInteractive)
        ) { [weak self] (result: Bool) -> Void in

            self?.processBiometryAuth(result: result)
        }
    }

    private func processBiometryAuth(result: Bool) {
        guard state == .checkingBiometry else {
            return
        }

        if result {
            state = .completed
            DispatchQueue.global(qos: .utility).async {
                self.presenter?.didCompleteAuth()
            }
            return
        }

        state = .waitingPincode
    }

    private func processStored(pin: String?) {
        guard state == .checkingPincode else {
            return
        }

        if pincode == pin {
            state = .completed
            pincode = nil
            DispatchQueue.global(qos: .utility).async {
                self.presenter?.didCompleteAuth()
            }

        } else {
            state = .waitingPincode
            pincode = nil
            DispatchQueue.global(qos: .userInteractive).async {
                self.presenter?.didEnterWrongPincode()
            }
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
        presenter = output
        guard state == .waitingPincode else { return }

        state = .checkingBiometry
        performBiometryAuth()
    }

    func process(pin: String) {
        guard state == .waitingPincode || state == .checkingBiometry else { return }

        pincode = pin

        state = .checkingPincode

        secretManager.loadSecret(
            for: KeystoreTag.pincode.rawValue,
            completionQueue: .global(qos: .userInteractive)
        ) { [weak self] (secret: SecretDataRepresentable?) -> Void in
            self?.processStored(pin: secret?.toUTF8String())
        }
    }
}
