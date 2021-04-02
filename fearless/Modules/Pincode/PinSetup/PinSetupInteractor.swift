import Foundation
import LocalAuthentication
import SoraKeystore

class PinSetupInteractor {
    enum PinSetupState {
        case waitingPincode
        case waitingBiometrics
        case submitingPincode
        case submitedPincode
    }

    weak var presenter: PinSetupInteractorOutputProtocol?

    private let secretManager: SecretStoreManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    private let biometryAuth: BiometryAuthProtocol
    private let locale: Locale

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

    private(set) var pincode: String?
    private(set) var state: PinSetupState = .waitingPincode {
        didSet(oldValue) {
            if oldValue != state {
                presenter?.didChangeState(from: oldValue)
            }
        }
    }

    private func handleNoneAuthType() {
        state = .submitingPincode
        submitPincode()
    }

    private func handleTouchId() {
        state = .waitingBiometrics

        presenter?.didStartWaitingBiometryDecision(type: .touchId) { [weak self] (result: Bool) -> Void in
            self?.processResponseForBiometrics(result: result)
        }
    }

    private func handleFaceId() {
        state = .waitingBiometrics

        let reason = R.string.localizable.askBiometryReason(preferredLanguages: locale.rLanguages)
        biometryAuth
            .authenticate(localizedReason: reason, completionQueue: .main) { [weak self] result in
                self?.processResponseForBiometrics(result: result)
            }
    }

    private func processResponseForBiometrics(result: Bool) {
        guard state == .waitingBiometrics else { return }

        settingsManager.biometryEnabled = result

        state = .submitingPincode

        submitPincode()
    }

    private func submitPincode() {
        guard state == .submitingPincode, let currentPincode = pincode else { return }

        secretManager.saveSecret(
            currentPincode,
            for: KeystoreTag.pincode.rawValue,
            completionQueue: DispatchQueue.main
        ) { _ -> Void in
            self.completeSetup()
        }
    }

    private func completeSetup() {
        state = .submitedPincode
        pincode = nil
        presenter?.didSavePin()
    }
}

extension PinSetupInteractor: PinSetupInteractorInputProtocol {
    func process(pin: String) {
        guard state == .waitingPincode else { return }

        pincode = pin

        switch biometryAuth.availableBiometryType {
        case .none:
            handleNoneAuthType()
        case .touchId:
            handleTouchId()
        case .faceId:
            handleFaceId()
        }
    }
}
