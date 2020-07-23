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

    weak var presenter: LocalAuthInteractorOutputProtocol?
    private(set) var secretManager: SecretStoreManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var biometryAuth: BiometryAuthProtocol
    private(set) var locale: Locale

    init(secretManager: SecretStoreManagerProtocol,
         settingsManager: SettingsManagerProtocol,
         biometryAuth: BiometryAuthProtocol,
         locale: Locale) {
        self.secretManager = secretManager
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
        self.locale = locale
    }

    private(set) var state = LocalAuthState.waitingPincode {
        didSet(oldValue) {
            if oldValue != state {
                presenter?.didChangeState(from: oldValue)
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
            completionQueue: DispatchQueue.main) { [weak self] (result: Bool) -> Void in

            self?.processBiometryAuth(result: result)
        }
    }

    private func processBiometryAuth(result: Bool) {
        guard state == .checkingBiometry else {
            return
        }

        if result {
           state = .completed
            presenter?.didCompleteAuth()
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
            presenter?.didCompleteAuth()
        } else {
            state = .waitingPincode
            pincode = nil
            presenter?.didEnterWrongPincode()
        }
    }
}

extension LocalAuthInteractor: LocalAuthInteractorInputProtocol {
    var allowManualBiometryAuth: Bool {
        return settingsManager.biometryEnabled == true && biometryAuth.availableBiometryType == .touchId
    }

    func startAuth() {
        guard state == .waitingPincode else { return }

        state = .checkingBiometry
        performBiometryAuth()
    }

    func process(pin: String) {
        guard state == .waitingPincode || state == .checkingBiometry else { return }

        self.pincode = pin

        state = .checkingPincode

        secretManager.loadSecret(for: KeystoreTag.pincode.rawValue,
                                 completionQueue: DispatchQueue.main
        ) { [weak self] (secret: SecretDataRepresentable?) -> Void in
            self?.processStored(pin: secret?.toUTF8String())
        }
    }
}
