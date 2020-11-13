import Foundation
import SoraKeystore

final class PinChangeInteractor {
    weak var presenter: PinSetupInteractorOutputProtocol?

    private(set) var secretManager: SecretStoreManagerProtocol

    init(secretManager: SecretStoreManagerProtocol) {
        self.secretManager = secretManager
    }
}

extension PinChangeInteractor: PinSetupInteractorInputProtocol {
    func process(pin: String) {
        secretManager.saveSecret(pin,
                                 for: KeystoreTag.pincode.rawValue,
                                 completionQueue: DispatchQueue.main) { [weak self] (_) -> Void in
            self?.presenter?.didSavePin()
        }
    }
}
