import Foundation
import LocalAuthentication
import SoraKeystore

class PinSetupInteractor {
    public enum PinSetupState {
        case waitingPincode
        case waitingBiometrics
        case submitingPincode
        case submitedPincode
    }

    weak var presenter: PinSetupInteractorOutputProtocol?

    private(set) var secretManager: SecretStoreManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var biometryAuth: BiometryAuthProtocol

    init(secretManager: SecretStoreManagerProtocol,
         settingsManager: SettingsManagerProtocol,
         biometryAuth: BiometryAuthProtocol) {
        self.secretManager = secretManager
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
    }

    private(set) var pincode: String?
    private(set) var state: PinSetupState = .waitingPincode {
        didSet(oldValue) {
            if oldValue != state {
                presenter?.didChangeState(from: oldValue)
            }
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

        secretManager.saveSecret(currentPincode,
                                 for: KeystoreTag.pincode.rawValue,
                                 completionQueue: DispatchQueue.main) { _ -> Void in
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

        self.pincode = pin

        let authType = biometryAuth.availableBiometryType
        if authType != .none {
            state = .waitingBiometrics

            presenter?.didStartWaitingBiometryDecision(type: authType) { [weak self] (result: Bool) -> Void in

                self?.processResponseForBiometrics(result: result)
            }

        } else {
            state = .submitingPincode
            submitPincode()
        }
    }
}
